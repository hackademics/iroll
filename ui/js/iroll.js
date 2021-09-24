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
    potIndex: 0,
    rolls: [],
    rollIndex: 0,
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
        await DApp.getPots();
        //console.log(await DApp.getBlockNumber());
        DApp.getPlayerRolls();
        DApp.getPlayerEscrow();
        DApp.getPlayerBalance();
        DApp.getRewardBalance();
        //console.log(await DApp.getPlayerEscrow());


        // $(".pit-pick-box").keyup(function(){
        //     if(this.value.length == this.maxLength){
        //         var $next = $(this).next('.pit-pick-box');
        //         $(this).next('.pit-pick-box').focus();
        //         //console.log($next);
        //         //if($next.length){
        //             //$(this).next('.pit-pick-box').focus();
        //         //} else {
        //             //$(this).blur();
        //         //}
        //     }
        // });

        DApp.hud_connect.hide();
        DApp.hud.fadeIn();
        return;     
    },
    allowed: async function(id) {
        return await DApp.contracts.IRoll.methods.allowed(1).call({ from: DApp.accounts[0] }).then((result) => {
            return true;
        }).catch((err) => {
            //console.log("err" + err);
            return false;
        });
    },
    roll:  async function(){
        if ($("#pot-uid").text() <= 0) { return; }

        var pot = await DApp.getPot($("#pot-uid").text());
        
        if (await DApp.allowed(pot.UID) == false){
           $("#pot-status").text("WAIT INTERVAL");
            return;
        }
        
        let picks = [$("#pp1").val(), $("#pp2").val(), $("#pp3").val(), $("#pp4").val(), $("#pp5").val()];

        for(let i=0;i<5;i++){
            if(picks[i] <= 0 || picks[i] > 6){
                $("#pot-status").text("INVALID PICKS");
                alert("INVALID PICKS");
                return;
            }
        }
        
        await DApp.showRolling();

        await DApp.contracts.IRoll.methods.roll(pot.UID, picks).send({
            from: DApp.accounts[0],
            gas: 1232731,
            value: pot.entry})       
            .on('receipt', function (receipt) {
                $(".fa-th").removeClass("fa-spin");
                let rv = receipt.events.Rolls.returnValues;
                DApp.bindRoll(rv);                
                //DApp.getPotRolls(pot.UID);
                
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
    getPot: async function (id) {
        return await DApp.contracts.IRoll.methods.getPot(id).call({ from: DApp.accounts[0] });
    },
    getPots: async function () {
        DApp.pots = await DApp.contracts.IRoll.methods.getPots().call({ from: DApp.accounts[0] });
        DApp.bindPot(DApp.pots[0]);
    },
    pagePots: async function (ele) {
        ele.toString().includes('forward') ? DApp.potIndex-- : DApp.potIndex++;
        if(DApp.potIndex >= DApp.pots.length) DApp.potIndex = 0;
        if(DApp.potIndex < 0) DApp.potIndex = DApp.pots.length - 1;
        return DApp.bindPot(DApp.pots[DApp.potIndex]);
    },
    getPotRolls: async function (_puid) {
        let options = { filter: { puid: [_puid] }, fromBlock: 0, toBlock: 'latest' };
        await DApp.contracts.IRoll.getPastEvents('Rolls', options).then((results) => {
            if (results) { results.reverse(); }
            return DApp.bindPotRolls(results);
        }).catch((err) => {
            return [];
        });
    }, 
    selectPot: async function () {
        if($("#pot-uid").text() <= 0) {return;}
        $("#pit-pot-balance").html("LOADING...");
        $("#pit-customroll").html("&nbsp;");
        $("#btn-roll").html("");
        $("#hud-center").css("opacity", "50%");
        setTimeout(() => {
            return DApp.getPot($("#pot-uid").text()).then((result) => {
                return DApp.bindPotPit(result);
            })
        }, 500);
        return ;
    },
    getPlayerRolls: async function(){
        let options = { filter: { plyr: [DApp.accounts[0]] }, fromBlock: 0, toBlock: 'latest' };
        return await DApp.contracts.IRoll.getPastEvents('Rolls', options).then((results) => {
            if (results) { results.reverse(); }  
            DApp.rolls = results;  
            $("#player-rolls").text(results.length);              
            return DApp.bindRoll(DApp.rolls[0].returnValues);
        }).catch((err) => {
            //alert(err);
        });
    },
    pageRolls: async function (ele) {
        ele.toString().includes('forward') ? DApp.rollIndex++ : DApp.rollIndex--;
        if (DApp.rollIndex >= DApp.rolls.length) DApp.rollIndex = 0;
        if (DApp.rollIndex < 0) DApp.rollIndex = DApp.rolls.length - 1;
        return DApp.bindPot(DApp.rolls[DApp.rollIndex]);
    },
    getPlayerEscrow: async function () {
        await DApp.contracts.IRoll.methods.payments(DApp.accounts[0]).call().then((result) => {
            var balance = DApp.web3.utils.fromWei(result, 'ether');
            var val = (balance).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            $("#player-escrow").text(val);
        }).catch((err) => {
            return 0;
        });
    },
    getPlayerBalance: async function () {
        await DApp.contracts.IRoll.methods.getPlayerBalance().call().then((result) => {
            var balance = DApp.web3.utils.fromWei(result, 'ether');
            var val = (balance).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            $("#player-balance").text(val);
        }).catch((err) => {
            return 0;
        });
    },    
    getRewardBalance: async function () {
        await DApp.contracts.IRoll.methods.getRewardBalance().call().then((result) => {
            var balance = DApp.web3.utils.fromWei(result, 'ether');
            var val = (balance).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
            $("#reward-balance").text(val);
        }).catch((err) => {
            //console.log("err" + err);
            return false;
        });
    },
    getBlockNumber: async function(){
        return DApp.web3.eth.getBlockNumber().then((result) => {
            return result;
        }).catch((err) => {
            //console.log(err);
        });
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
        .on('receipt', function (receipt) {
            //console.log(receipt);
            DApp.bindPot(uid);
        })
        .on('error', function (error, receipt) {
            console.log(error);
            //console.log(receipt);
        });
        
    },
    createPot: async function () {
        let wallet = $("#txtWallet").val();
        let entry = DApp.web3.utils.toBN($("#txtEntryFee").val() * 10 ** 18);
        let interval = DApp.web3.utils.toBN($("#txtInterval").val());
        let seed = $("#txtSeed").val();
        let fee = $("#txtFee").val();
        let sixes = $("#cbSixes").prop("checked");
        let picks = $("#cbPicks").prop("checked");
        let custom = $("#cbCustom").prop("checked");
        let customRoll = [$("#cr0").val(), $("#cr1").val(), $("#cr2").val(), $("#cr3").val(), $("#cr4").val()];
        let rewards = [$("#rwd0").val(), $("#rwd1").val(), $("#rwd2").val(), $("#rwd3").val(), $("#rwd4").val(), $("#rwd5").val(), $("#rwd6").val(), $("#rwd7").val(), $("#rwd8").val(), $("#rwd9").val(), $("#rwd10").val()];
        
        return true;
    },
    bindResultDice: function (arr) {
        for (var i = 0; i < arr.length; i++) {
            const dnum = arr[i];
            const img = '<img src="../img/d-' + dnum + '.png" style="padding-top:12px;width:40px" />';
            const sel = "#d" + (i + 1);
            $(sel).html(img);
            $(".pit-circle").css("background-color", "#BB4100");
        }
    },
    bindRoll: function (rv) {
        if(rv.puid <= 0){return;}

        DApp.getPot(rv.puid).then((result) => {
            let combo = DApp.getCombo(rv.rwd, result.rewards);
            $("#roll-combo").text(combo);
        });
        let d = DApp.toDice(rv.di, 16);
        let p = DApp.toDice(rv.pi, 12);

        $("#roll-vrfId").text(rv.vrfid.substring(0, 15) + "..");
        $("#roll-puid").text(rv.puid);
        $("#roll-payout").html(DApp.web3.utils.fromWei(rv.amt, 'ether') + " <small>ETH</small>");
        $("#roll-tokens").html(DApp.web3.utils.fromWei(rv.rwd, 'ether') + " <small>IROLL</small>");
        $("#roll-dice").html(d);
        $("#roll-picks").html(p);

        return;
    },
    bindPot: async function (id) {

        const pot = await DApp.getPot(id);

        let d = DApp.toDice(pot.customRoll, 15);

        $("#pot-uid").text(pot.UID);
        $("#pot-balance").text(DApp.web3.utils.fromWei(pot.balance, 'ether'));
        $("#pot-entry").text(DApp.web3.utils.fromWei(pot.entry, 'ether'));
        $("#pot-seed").text(pot.seed);
        $("#pot-interval").html(pot.interval + " <small>SECONDS</small>");
        $("#pot-owner").text(pot.owner.substring(0, 14) + "..");
        $("#pot-sixes").text(pot.sixes ? "REQUIRED" : "NOT REQUIRED");
        $("#pot-picks").text(pot.picks ? "WINS JACKPOT" : "NO JACKPOT");
        $("#pot-custom").text(pot.custom ? "WINS JACKPOT" : "NO JACKPOT");
        $("#pot-customroll").html(d);
        $("#pot-rwd0").text(DApp.web3.utils.fromWei(pot.rewards[0], 'ether'));
        $("#pot-rwd1").text(DApp.web3.utils.fromWei(pot.rewards[1], 'ether'));
        $("#pot-rwd2").text(DApp.web3.utils.fromWei(pot.rewards[2], 'ether'));
        $("#pot-rwd3").text(DApp.web3.utils.fromWei(pot.rewards[3], 'ether'));
        $("#pot-rwd4").text(DApp.web3.utils.fromWei(pot.rewards[4], 'ether'));
        $("#pot-rwd5").text(DApp.web3.utils.fromWei(pot.rewards[5], 'ether'));
        $("#pot-rwd6").text(DApp.web3.utils.fromWei(pot.rewards[6], 'ether'));
        $("#pot-rwd7").text(DApp.web3.utils.fromWei(pot.rewards[7], 'ether'));
        $("#pot-rwd8").text(DApp.web3.utils.fromWei(pot.rewards[8], 'ether'));
        $("#pot-rwd9").text(DApp.web3.utils.fromWei(pot.rewards[9], 'ether'));
        $("#pot-rwd10").text(DApp.web3.utils.fromWei(pot.rewards[10], 'ether'));

        return;
    },
    bindPotPit: async function (pot) {
        $("#hud-center").css("opacity", "100%");
        $("#pit").css("background-color", "#3B673B");
        let d = DApp.toDice(pot.customRoll, 20);
        $("#pit-customroll").html(d);

        $("#pit-pot-balance").html(DApp.web3.utils.fromWei(pot.balance, "ether") + " ETH <br /><br /> POT # " + pot.UID);
        $("#btn-roll").html(DApp.web3.utils.fromWei(pot.entry, "ether") + " ETH<br /><br /> ROLL DICE");
        $("#pit-pot-noentry").hide();
        $("#pot-status").text("WAITING FOR BUY IN");

        await DApp.getPotRolls(pot.UID);

        return;

    },
    bindPotRolls: function(results) {

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

        for (let i = 0; i < results.length; i++) {
            let tr = document.createElement('tr');
            tblBody.appendChild(tr);

            let td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(document.createTextNode(results[i].returnValues.plyr.substring(0, 18) + ".."));

            let dice = DApp.toDice(results[i].returnValues.di, 13);
            let div = document.createElement("div");
            div.innerHTML = dice;
            td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(div);

            td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(document.createTextNode(DApp.web3.utils.fromWei(results[i].returnValues.rwd, 'ether')));

            td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(document.createTextNode(results[i].returnValues.amt));
        }

        console.log(table);

        $("#pot-history").html(table);

        return;
    },
    showRolling: async function () {
        $("#pot-status").text("ROLLING..");
        $("#d1").text("?");
        $("#d2").text("?");
        $("#d3").text("?");
        $("#d4").text("?");
        $("#d5").text("?");
        $(".pit-circle").css("background-color", "#3B673B");
        $(".fa-th").addClass("fa-spin");
    },
    showRollComplete: async function () {
        $("#pot-status").text("ROLLING..");
        $(".pit-circle").css("background-color", "#3B673B");
        $(".fa-th").addClass("fa-spin");
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
    },
    toDice: function(arr, w){
        let d = '';
        for (var i = 0; i < arr.length; i++) {
            d = d + "<img src='../img/d-" + arr[i] + ".png' style='width:" + w + "px;background-color:#BB4100;border-radius:5px 5px 5px 5px;margin-right:2px;padding:5px;' />";
        }
        return d;
    },
    getCombo: function(rwd, rwds){
        switch (rwd) {
            case rwds[10]:
                return "SINGLE PAIR";
            case rwds[9]:
                return "TWO PAIR";
            case rwds[8]:
                return "THREE OF A KIND";
            case rwds[7]:
                return "SMALL STRAIGHT";
            case rwds[6]:
                return "FULL HOUSE";
            case rwds[5]:
                return "LARGE STRAIGHT";
            case rwds[4]:
                return "FOUR OF A KIND";
            case rwds[3]:
                return "CUSTOM ROLL";
            case rwds[2]:
                return "PLAYER PICK";
            case rwds[1]:
                return "ALL SIXES";
            case rwds[0]:
                return "JACKPOT";
            default:
                return "BUPKIS";
        }
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