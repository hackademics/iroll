document.addEventListener('DOMContentLoaded', onDocumentLoad);
//INIT DAPP
function onDocumentLoad() {
    DApp.init();
}

const DApp = {
    web3: null,
    contracts: {},
    accounts: [],
    pots: [],
    potRolls: [],
    playerRolls: [],
    currentPoolUID: 0,
    initd: false,

    //display elements
    hud: $("#hud"),
    hud_connect: $("#hud-connect"),
    hud_left: $("#hud-left"),
    hud_center: $("#hud-center"),
    hud_left: $("#hud-right"),

    init: function() {
        if(DApp.initd){return;}
        DApp.initd = true;
    },
    connect: async function() {
        if(typeof window.ethereum !== 'undefined'){
            try{
                DApp.web3 =  new Web3(window.ethereum);
                const accts = await window.ethereum.request({method:'eth_requestAccounts'});
                DApp.updateAccounts(accts);
                window.ethereum.autoRefreshOnNetworkChange = false;
                window.ethereum.on('accountsChanged', DApp.updateAccounts);
            }catch(error){
                //console.log(error);
                return;
            }
        }else if(window.web3){
            DApp.web3 = new Web3(web3.currentProvider);
        } else {
            //console.log("404");
            return;
        }
        return this.initContracts();
    },
    disconnect: async function() {
        DApp.web3 = null;
        DApp.contracts = {};
        DApp.accounts = [];
    },
    connected: async function(){
        return (DApp.web3 !== null && DApp.accounts.length > 0);
    },
    updateAccounts: async function(accts){
        DApp.accounts = accts || await DApp.web3.eth.getAccounts();
    },
    initContracts: async function () {        
        const netId = await DApp.web3.eth.net.getId();
        try{
            DApp.getContractJSON('build/contracts/IRoll.json').then(function (data) {
                if (!data.networks[netId]) {
                    console.log(data.networks);
                    alert("IRoll contract not found on the network you are currently connected to.");
                    return;
                } else {
                    DApp.contracts.IRoll = new DApp.web3.eth.Contract(data.abi, data.networks[netId].address);
                    return DApp.initHud();
                }  
            });            
        }catch(error){
            console.log(error);
            alert('An error occurred accessing contracts');
        }        
        return;
    },
    getContractJSON: async function (src) {
        return $.getJSON(src).then(function (data) {
            return data;
        });
    },
    initHud: async function() {
        await DApp.fetchPots();
        //await DApp.fetchPlayerRolls();     
        await DApp.getRolls();
        //await DApp.bindPotHistory(1);

        DApp.hud_connect.hide();
        DApp.hud.fadeIn();
        return;     
    },
    roll:  async function(){
        if (DApp.currentPoolUID <= 0) {
            return;
        }    

        var pot = await DApp.getPot(DApp.currentPoolUID);
        if (!await DApp.allowed(pot.UID)){
           $("#pot-status").text("WAIT INTERVAL");
            return;
        }

        const pp1 = $("#pp1").val();
        const pp2 = $("#pp2").val();
        const pp3 = $("#pp3").val();
        const pp4 = $("#pp4").val();
        const pp5 = $("#pp5").val();
        let picks = [pp1, pp2, pp3, pp4, pp5];

        for(let i=0;i<5;i++){
            if(picks[i] <= 0 || picks[i] > 6){
                $("#pot-status").text("INVALID PICKS");
                alert("INVALID PICKS");
                return;
            }
        }

        await DApp.renderRolling();

        $("#pot-status").text("ROLLING..");

        console.log(pot.entry);

        await DApp.contracts.IRoll.methods.roll(pot.UID, picks).send({
            from: DApp.accounts[0],
            gas: 2344935,
            value: pot.entry
        }).on('transactionHash', function (hash) {
            //$("#pot-status").text("ROLLING..");
        })
        .on('receipt', function (receipt) {
            let rv = receipt.events.Fin.returnValues;
            for(var i=0;i<rv.di.length;i++){
                const dnum = rv.di[i];
                const img = '<img src="../img/d-' + dnum + '.png" style="padding-top:12px;width:40px" />';
                const sel = "#d" + (i + 1);
                $(sel).html(img);
                $(".pit-circle").css("background-color", "#BB4100");
            }
            $("#roll-uid").text(rv.ruid);
            $("#roll-vrfId").text(rv.vrfid.substring(0,15) + "..");
            $("#roll-puid").text("#" + rv.puid);
            $("#roll-payout").text(rv.amt + " ETH");
            $("#roll-tokens").text(rv.rwd + " IROLL");

            let combo = "";
            switch (rv.rwd){
                case pot.rewards[10]:
                    combo = "SINGLE PAIR";
                    break;
                case pot.rewards[9]:
                    combo = "TWO PAIR";
                    break;
                case pot.rewards[8]:
                    combo = "THREE OF A KIND";
                    break;
                case pot.rewards[7]:
                    combo = "SMALL STRAIGHT";
                    break;
                case pot.rewards[6]:
                    combo = "FULL HOUSE";
                    break;
                case pot.rewards[5]:
                    combo = "LARGE STRAIGHT";
                    break;
                case pot.rewards[4]:
                    combo = "FOUR OF A KIND";
                    break;
                case pot.rewards[3]:
                    combo = "CUSTOM ROLL";
                    break;
                case pot.rewards[2]:
                    combo = "PLAYER PICK";
                    break;
                case pot.rewards[1]:
                    combo = "ALL SIXES";
                    break;
                case pot.rewards[0]:
                    combo = "JACKPOT";
                    break;
                default:
                    combo = "BUPKIS";
                    break;
            }
            
            let d = '';
            for (var i = 0; i < rv.di.length; i++) {
                d = d + "<img src='../img/d-" + rv.di[i] + ".png' style='width:15px;background-color:#BB4100;border-radius:5px 5px 5px 5px;margin-right:2px;padding:5px;' />";
            }

            let p = '';
            for (var i = 0; i < rv.pi.length; i++) {
                p = p + "<img src='../img/d-" + rv.pi[i] + ".png' style='width:15px;background-color:#BB4100;border-radius:5px 5px 5px 5px;margin-right:2px;padding:5px;' />";
            }

            $("#roll-dice").html(d);
            $("#roll-picks").html(p);
            $("#roll-combo").text(combo);
            $("#pot-status").text("DONE: " + combo);            

            DApp.bindPotHistory(pot.UID);
            $(".fa-th").removeClass("fa-spin");
            
        })
        .on('confirmation', function (confirmatnNumber, receipt) {
            //console.log(receipt);
        })
        .on('error', function (error, receipt) {
            if (error.message.includes("revert wait")){
                $("#pot-status").text("WAIT INTERVAL");
            } else {
                $("#pot-status").text("FAILED");
            }

            $(".fa-th").removeClass("fa-spin");
        });

       

        return;
        
    },
    bindPotHistory: async function(_puid){
        let options = {
            filter:{puid:[_puid]},
            fromBlock: 0,
            toBlock: 'latest'
        };
        DApp.contracts.IRoll.getPastEvents('Fin', options)
            .then((results) => {
                results.reverse();

                let table = document.createElement("table");
                table.className = "list";

                let tblHead = document.createElement("thead");
                table.append(tblHead);

                let trh = document.createElement('tr');
                tblHead.appendChild(trh);

                let th = document.createElement("th");
                trh.appendChild(th);
                th.appendChild(document.createTextNode("PLAYER"));

                th = document.createElement("th");
                trh.appendChild(th);
                th.appendChild(document.createTextNode("DICE"));

                th = document.createElement("th");
                trh.appendChild(th);
                th.appendChild(document.createTextNode("IROLL"));

                th = document.createElement("th");
                trh.appendChild(th);
                th.appendChild(document.createTextNode("ETH"));

                let tblBody = document.createElement("tbody");
                table.append(tblBody);
                
                for(let i=0;i<results.length;i++){
                    let tr = document.createElement('tr');
                    tblBody.appendChild(tr);

                    let td = document.createElement("td");
                    tr.appendChild(td);
                    td.appendChild(document.createTextNode(results[i].returnValues.ms.substring(0,18) + ".."));
                   
                    td = document.createElement("td");
                    tr.appendChild(td);
                    td.appendChild(document.createTextNode(results[i].returnValues.di));

                    td = document.createElement("td");
                    tr.appendChild(td);
                    td.appendChild(document.createTextNode(results[i].returnValues.rwd));

                    td = document.createElement("td");
                    tr.appendChild(td);
                    td.appendChild(document.createTextNode(results[i].returnValues.amt));
                }

                $("#pot-history").html(table);

            })
            .catch((err) => {
                console.log(err);
            });
    },
    allowed: async function(id){
        // DApp.contracts.IRoll.methods.allowed(id).call({ from: DApp.accounts[0] }).then((result) => {
        //     console.log("res" + result);
        //     return true;
        // }).catch((err) => {
        //     console.log("err" + err);
        //     return false;
        // });
        return true;
    },
    getPot: async function (id) {
       return await DApp.contracts.IRoll.methods.getPot(id).call({ from: DApp.accounts[0] });
    },
    seedPot: async function(){   
        let uid = $("#pot-uid").text();
        if(uid <= 0){
            return;
        }

        DApp.contracts.IRoll.methods.seedPot(uid).send({
            from: DApp.accounts[0],
            gas: 1333473,
            value: DApp.web3.utils.toBN(.01 * 10 ** 18)
        })
        .on('transactionHash', function(hash){
            //console.log(hash);
        })
        .on('receipt', function (receipt) {
            //console.log(receipt);
            DApp.bindPot(uid - 1);
        })
        .on('confirmation', function (confirmatnNumber, receipt) {
            //console.log(receipt);
        })
        .on('error', function (error, receipt) {
            //console.log(error);
            //console.log(receipt);
        });
        
    },
    loadPool: async function(id){
        const pool = await DApp.getPot(id);

        let d = '';
        for (var i = 0; i < pool.customRoll.length; i++) {
            d = d + "<img src='../img/d-" + pool.customRoll[i] + ".png' style='width:20px;background-color:#BB4100;border-radius:5px 5px 5px 5px;margin-right:5px;padding:5px;' />";
        }

        $("#pit-customroll").html(d);

        $("#pit-pot-balance").text(DApp.web3.utils.fromWei(pool.balance, "ether") + " ETH  # " + pool.UID);
        $("#btn-roll").text(DApp.web3.utils.fromWei(pool.entry, "ether") + " ETH BUY IN");
        $("#pit-pot-noentry").hide();
        $("#pot-status").text("AWAITING BUY IN");

        alert("POT # " + id + " HAS BEEN SELECTED");

        await DApp.bindPotHistory(id)

    },
    bindPot: async function(index){
        
        let id = DApp.pots[index].UID;
        const pot = await DApp.getPot(id);
        
        let d = '';
        for(var i=0;i<pot.customRoll.length;i++){
            d = d + "<img src='../img/d-" + pot.customRoll[i] + ".png' style='width:15px;background-color:#BB4100;border-radius:5px 5px 5px 5px;margin-right:2px;padding:5px;' />";
        }
        
        $("#pot-uid").text(pot.UID);
        $("#pot-balance").text(DApp.web3.utils.fromWei(pot.balance, 'ether'));
        $("#pot-tokens").text(pot.rewards[0]);
        $("#pot-entry").text(DApp.web3.utils.fromWei(pot.entry, 'ether'));
        $("#pot-seed").text(pot.seed);
        $("#pot-interval").text(pot.interval + " SECONDS");
        $("#pot-owner").text(pot.owner.substring(0,10) + "...");
        $("#pot-sixes").text(pot.sixes ? "YES" : "NO");
        $("#pot-picks").text(pot.picks ? "YES" : "NO");
        $("#pot-custom").text(pot.custom ? "YES" : "NO");
        $("#pot-customroll").html(d);
        $("#pot-rwd4").text(pot.rewards[4]);
        $("#pot-rwd5").text(pot.rewards[5]);
        $("#pot-rwd6").text(pot.rewards[6]);
        $("#pot-rwd7").text(pot.rewards[7]);
        $("#pot-rwd8").text(pot.rewards[8]);
        $("#pot-rwd9").text(pot.rewards[9]);
        $("#pot-rwd10").text(pot.rewards[10]);

        return;
    },
    bindPlayerPot: async function(roll) {
        $("#roll-uid").text(roll.UID);
        $("#pot-payout").text(DApp.web3.utils.fromWei(roll.payout, 'ether'));
    },
    fetchPlayerRolls: async function () {
        const rolls = await DApp.contracts.IRoll.methods.getRolls().call({ from: DApp.accounts[0] });
        console.log(rolls);
        // if(DApp.playerRolls.length > 0){
        //     DApp.bindPlayerRoll(DApp.playerRolls[0]);
        //     $("#player-rolls").show();
        //     $("#player-rolls-pager").show();
        //     $("#no-rolls").hide();
        // } else {
        //     $("#player-rolls").hide();
        //     $("#player-rolls-pager").hide();
        // } 
        return;       
    },
    getRolls: async function () {
        //const t = await DApp.contracts.IRoll.methods.getRolls().call({ from: DApp.accounts[0] });
        //console.log(t);
        return;

    },
    getRoll: async function () {
        const rolls = await DApp.contracts.IRoll.methods.getRoll(1).call({ from: DApp.accounts[0] });
        console.log(rolls);
        return;

    },
    fetchPotRolls: async function () {

    },
    fetchPots: async function () {
        DApp.pots = await DApp.contracts.IRoll.methods.getPots().call({ from: DApp.accounts[0] });
        //console.log(DApp.pots[0]);
        return DApp.bindPot(0);
    },
    previousPot: async function(){
        let index = $("#pot-uid").text() - 1;
        index = (index <= 0) ? DApp.pots.length - 1 : index - 1;
        return DApp.bindPot(index);
        
    },
    nextPot: async function() {
        let index = $("#pot-uid").text() - 1;
        index = (index >= DApp.pots.length - 1) ? 0 : index + 1;
        return DApp.bindPot(index);
    },
    selectPot: async function () {
        DApp.currentPoolUID = $("#pot-uid").text();
        //$("#pool-uid").val(uid);
        //console.log(DApp.currentPoolUID);
        DApp.loadPool(DApp.currentPoolUID);
        
    },
    previousRoll: async function () {
        //let index = $("#roll-uid").text() - 1;
        //index = (index < 0) ? DApp.pots.length - 1 : index - 1;
        //DApp.bindPot(DApp.pots[index]);

    },
    nextRoll: async function () {
        //let index = $("#roll-uid").text() - 1;
        //index = (index >= DApp.pots.length) ? 0 : index + 1;
        //DApp.bindPot(DApp.pots[index]);
    },
    selectRoll: async function () {
        $("#roll-uid").text();
    },
    renderRolling: async function(){
        $("#d1").text("?");
        $("#d2").text("?");
        $("#d3").text("?");
        $("#d4").text("?");
        $("#d5").text("?");
        $(".pit-circle").css("background-color", "#3B673B");
        $(".fa-th").addClass("fa-spin");
    },
    createPot: async function () {
        let wallet = $("#txtWallet").val();
        let entry = DApp.web3.utils.toBN($("#txtEntryFee").val() * 10 ** 18);//;
        let interval = DApp.web3.utils.toBN($("#txtInterval").val());
        let seed = $("#txtSeed").val();
        let fee = $("#txtFee").val();
        let sixes = $("#cbSixes").prop("checked");
        let picks = $("#cbPicks").prop("checked");
        let custom = $("#cbCustom").prop("checked");
        let customRoll = [$("#cr0").val(), $("#cr1").val(), $("#cr2").val(), $("#cr3").val(), $("#cr4").val()];
        let rewards = [$("#rwd0").val(), $("#rwd1").val(), $("#rwd2").val(), $("#rwd3").val(), $("#rwd4").val(), $("#rwd5").val(), $("#rwd6").val(), $("#rwd7").val(), $("#rwd8").val(), $("#rwd9").val(), $("#rwd10").val()];
        
        try{
            // await DApp.contracts.IRoll.methods.createPot(
            //     wallet,
            //     entry,
            //     interval,
            //     seed,
            //     fee,
            //     sixes,
            //     picks,
            //     custom,
            //     customRoll,
            //     rewards)
            //     .send(function(error, result){
            //         console.log(result);
            //         //console.log(error);
            //     });
            //DApp.contracts.IRoll.methods.mockPot().send({ from: DApp.accounts[0] }, function (receipt) {
                //console.log(receipt);
            //});
            
            
        }catch(error){
            //console.log(error);
            return false;
        }
        return true;
    },
    mapNum: function(num){
        switch(num){
            case "1":
                return "one";
            case "2":
                return "two";
            case "3":
                return "three";
            case "4":
                return "four";
            case "5":
                return "five";
            case "6":
                return "six";
        }
        return;
    }
};



/**
 * DICE 
 **/
const Dice = {
    id: null,
    count: 5,
    sides: 6,
    width: 50,
    height: 50,
    indexer: 1,
    spinTimer: null,
    selectedDice: [0, 0, 0, 0, 0],
    sideOrder: [2, 5, 3, 4, 1, 6],

    /**
     * INITIALIZE
     **/
    init: function () {
        Dice.loadDice();
    },

    /**
     * Event when player clicks on a dice
     **/
    select: function () {
        var die = parseInt(this.id[4]);
        var side = parseInt(this.id[11]);
        Dice.selectedDice[(die - 1)] = side;
        document.getElementById("d" + die + "-selection").innerText = side;
    },

    /**
     * Transform the requested side for a selected 3D
     * @param {number} dieId
     * @param {number} side
     */
    showDieSide: function (dieId, side) {
        var target = document.getElementById("die-" + dieId);
        target.style.transform = Dice.getDisplayTransform(side);
    },

    /**
     * Spin the dice by incrementing by 1 for player selection
     **/
    spin: function () {
        var cnt = 0;
        for (i = 0; i < Dice.selectedDice.length; i++) {
            var sd = Dice.selectedDice[i];
            if (sd > 0) {
                cnt++;
            } else {
                //Die is not selected so increment it's side number 
                Dice.indexer = Dice.indexer <= 6 ? Dice.indexer : 1;
                Dice.showDieSide((i + 1), Dice.indexer);
            }
        }

        //increment the indexer
        Dice.indexer++;

        //if all 5 dice selected then stop timer
        if (cnt >= 5) {
            clearTimeout(Dice.spinTimer);
        }

        Dice.spinTimer = setTimeout(Dice.spin, 1500);
    },

    /**
     * Create five individual 3D dice that can spin and be selected
     **/
    loadDice: function () {
        $("#d1").append(Dice.createDieCube(1));
        $("#d2").append(Dice.createDieCube(2));
        $("#d3").append(Dice.createDieCube(3));
        $("#d4").append(Dice.createDieCube(4));
        $("#d5").append(Dice.createDieCube(5));

        Dice.spin();
    },

    /**
     * Create a 3D representation of a die that can spin
     * @param {any} dieId
     */
    createDieCube: function (dieId) {
        var cube = document.createElement('div');
        cube.className = "cube";
        cube.id = "cube-" + dieId;

        var die = document.createElement('div');
        die.id = "die-" + dieId;
        die.className = "die";

        die.appendChild(Dice.createDieSide(dieId, 2, 50));
        die.appendChild(Dice.createDieSide(dieId, 5, 50));
        die.appendChild(Dice.createDieSide(dieId, 3, 50));
        die.appendChild(Dice.createDieSide(dieId, 4, 50));
        die.appendChild(Dice.createDieSide(dieId, 1, 50));
        die.appendChild(Dice.createDieSide(dieId, 6, 50));

        cube.append(die);

        return cube;
    },

    /**
     * Create the face of a die side without images
     * @param {number} dieId
     * @param {number} side
     * @param {number} width
     */
    createDieSide: function (dieId, side, width) {
        var dieSide = document.createElement('div');
        dieSide.id = "die-" + dieId + "-side-" + side;
        dieSide.className = "die-side";
        dieSide.onclick = Dice.select;

        var grid = Dice.getDieGrid(side);
        var tbl = document.createElement('table');
        dieSide.appendChild(tbl);
        tbl.className = "die-grid";
        tbl.style.width = "100%";
        tbl.style.height = "100%";

        for (i = 0; i < grid.length; i++) {
            var tr = document.createElement('tr');
            for (j = 0; j < grid[i].length; j++) {
                var td = document.createElement('td');
                var div = document.createElement('div');
                div.className = grid[i][j] == 1 ? 'dot' : '';
                td.appendChild(div);
                tr.appendChild(td);
            }
            tbl.appendChild(tr);
        }
        dieSide.style.transform = Dice.getInitTransform(side);
        return dieSide;
    },

    /**
     * Get the 3x3 grid that displays the dice side
     * @param {number} side
     */
    getDieGrid: function (side) {
        switch (side) {
            case 1:
                return [[0, 0, 0], [0, 1, 0], [0, 0, 0]];
            case 2:
                return [[0, 0, 1], [0, 0, 0], [1, 0, 0]];
            case 3:
                return [[0, 0, 1], [0, 1, 0], [1, 0, 0]];
            case 4:
                return [[1, 0, 1], [0, 0, 0], [1, 0, 1]];
            case 5:
                return [[1, 0, 1], [0, 1, 0], [1, 0, 1]];
            case 6:
                return [[1, 0, 1], [1, 0, 1], [1, 0, 1]];
            default:
                return [[0, 0, 0], [0, 0, 0], [0, 0, 0]];
        }
    },

    /**
     * Get the degree required to spin 3D cube to requested side
     * @param {number} side
     */
    getDisplayTransform: function (side) {
        switch (side) {
            case 1:
                return "translateZ(-25px) rotateX(-90deg)";
            case 2:
                return "translateZ(-25px) rotateY(0deg)";
            case 3:
                return "translateZ(-25px) rotateY(-180deg)";
            case 4:
                return "translateZ(-25px) rotateY(90deg)";
            case 5:
                return "translateZ(-25px) rotateY(-90deg)";
            case 6:
                return "translateZ(-25px) rotateX(90deg)";
        }
    },
    /**
     * Get the degrees required to transform 3D cube on init
     * @param {number} side
     */
    getInitTransform: function (side) {
        switch (side) {
            case 1:
                return "rotateX(90deg) translateZ(25px)";
            case 2:
                return "rotateY(0deg) translateZ(25px)";
            case 3:
                return "rotateY(180deg) translateZ(25px)";
            case 4:
                return "rotateY(-90deg) translateZ(25px)";
            case 5:
                return "rotateY(90deg) translateZ(25px)";
            case 6:
                return "rotateX(-90deg) translateZ(25px)";
        }
    },
    /**
     * Get a Random Number in a range between a Min and Max value
     * @param {number} min
     * @param {number} max
     */
    getRandomRange: function (min, max) {
        return Math.floor(Math.random() * (max - min + 1) + min);
    },

}