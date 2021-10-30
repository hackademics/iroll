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
    potSelected: 0,
    pot: null,
    rewards:[],
    rolls: [],
    rollIndex: 0,
    colors: [],
    ethBalance: 0,
    irollBalance: 0,
    tvl: 0,
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
        DApp.bindPotSearch();

        DApp.potSelected = DApp.getQueryString();

        DApp.colors = ["#3B673B", "#42708F", "#13253E", "#BB4100", "#C6551B", "#417066", "#3E2A65", "#C8561B", "#569184", "#4B2285"];
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
                console.log(error);
                return;
            }
        }else if(window.web3){
            DApp.web3 = new Web3(web3.currentProvider);
        } else {
            console.log("404");
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
        await DApp.getPlayerRolls();
        await DApp.getPlayerInfo();
        await DApp.getRewards();
        await DApp.getPots();
        if(DApp.potSelected > 0){
            DApp.potIndex = DApp.potSelected - 1;
            await DApp.selectPot(DApp.potSelected);
            await DApp.bindPot(DApp.potSelected);
            
        } else {
            DApp.potSelected = 1;
            await DApp.selectPot(DApp.potSelected);
            await DApp.bindPot(DApp.potSelected);
        }

        $("#pot-backward").on("click", () => {
            DApp.potIndex--;
            DApp.pagePots();
        });

        $("#pot-forward").on("click", () => {
            DApp.potIndex++;
            DApp.pagePots();
        })
        
        $("#pot-search").show();
        $("#iroll-rewards").show();
        DApp.hud_connect.hide();
        DApp.hud.fadeIn();
        return;     
    },
    getRollGas: async function(puid, entry){
        return await DApp.contracts.IRoll.methods.roll(puid).estimateGas({
            from: DApp.accounts[0],
            gasPrice: DApp.web3.utils.gasPrice,
            value: entry
        }, function(err, estimatedGas){
            return estimatedGas;
        });
    },
    allowed: async function(id) {
        return await DApp.contracts.IRoll.methods.getPlayerNextRoll(id).call({ from: DApp.accounts[0] }).then((result) => {
            const now = new Date();
            const utc = now.getTime() + (now.getTimezoneOffset() * 60 * 1000);
            const secs = Math.round(utc/1000);

            console.log(secs);
            
           return result[0] == 0 || result[0] <= result[1];
        }).catch((error) => {
            console.log(error);
            return false;
        });
    },
    roll:  async function(){
        if (DApp.pot == null || DApp.pot.UID == 0) { return; }
      
        if (await DApp.allowed(DApp.pot.UID) == false){
           $("#pot-status").text("WAIT INTERVAL");
            return;
        }       
        
        await DApp.showRolling();

        let gasEstimate = await DApp.getRollGas(DApp.pot.UID, DApp.pot.entry);
        console.log(gasEstimate);

        await DApp.contracts.IRoll.methods.roll(DApp.pot.UID).send({
            from: DApp.accounts[0],
            gas: 162272,
            value: DApp.pot.entry})       
            .on('receipt', function (receipt) {
                DApp.getPlayerRolls();
                DApp.getPotRolls(DApp.pot.UID);
                DApp.bindResultDice(receipt.events.Rolls.returnValues.dice);
                let combo = DApp.getCombo(receipt.events.Rolls.returnValues.reward);
                return DApp.showRollComplete(combo);
            })
            .on('error', function (error, receipt) {
                if (error.message.includes("revert wait")){
                    $("#pot-status").text("WAIT INTERVAL");
                } else {
                    $("#pot-status").text("TRANSACTION FAILED");
                }                
                return DApp.showRollFailed();
            });       

        return;
        
    },
    getPot: async function (puid) {     
        if (DApp.pot != null && DApp.pot.UID == puid) { return DApp.pot;}
        DApp.pot = await DApp.contracts.IRoll.methods.getPot(puid).call({ from: DApp.accounts[0] });
        return DApp.pot;
    },
    getPots: async function () {
        DApp.pots = await DApp.contracts.IRoll.methods.getPots().call({ from: DApp.accounts[0] });
    },
    pagePots: async function () {
        if(DApp.potIndex >= DApp.pots.length) DApp.potIndex = 0;
        if(DApp.potIndex < 0) DApp.potIndex = DApp.pots.length - 1;
        return DApp.bindPot(DApp.pots[DApp.potIndex]);
    },
    getPotRolls: async function (_puid) {   
        $("#pot-history").html("<i class='fa-solid fa-spinner fa-spin'></i>");
        let options = { filter: { puid: [_puid] }, fromBlock: 0, toBlock: 'latest' };
        await DApp.contracts.IRoll.getPastEvents('Rolls', options).then((results) => {
            if (results) { results.reverse(); }
            return DApp.bindPotRolls(results);
        }).catch((err) => {
            console.log(err);
            return;
        });
    }, 
    selectPot: async function (puid) {        
        DApp.potSelected = puid > 0 ? puid : $("#pot-uid").val();        
        if (DApp.potSelected  > (DApp.pots.length)) { return; }
        DApp.pot = await DApp.getPot(DApp.potSelected);
        $("#player-pot").text("#" + DApp.pot.UID);
        await DApp.getPotRolls(DApp.pot.UID);
        return DApp.bindPotPit(DApp.pot);
        //console.log(pot);
        // $("#pot-history").html("<i class='fa-solid fa-spinner fa-spin'></i>");
        // $("#pit-pot-balance").html("LOADING...");
        // $("#pit-pot-entry").html("");
        // $("#pit-pot-uid").html("");
        // $("#btn-roll").html("");
        // $("#hud-center").css("opacity", "50%");
        // $(".pit-circle").css("background-color", "#3B673B");
        // $("#pot-rolls-header").css("background-color", DApp.getPotColor(puid));
        // $("#pot-rolls-header").text("POT #" + puid + " ROLLS");
        // $("#d1").text("?");
        // $("#d2").text("?");
        // $("#d3").text("?");
        // $("#d4").text("?");
        // $("#d5").text("?");
        // setTimeout(() => {
        //     return DApp.getPot(puid).then((result) => {
        //         return DApp.bindPotPit(result);
        //     })
        // }, 500);
        return ;
    },
    getQueryString: function () {
        const urlParams = new URLSearchParams(window.location.search);
        const qs = Object.fromEntries(urlParams.entries());
        return qs["p"];
    },
    searchPot: function() {
        let puid = $("#search-puid").val();
        if (puid > 0) {
            DApp.selectPot(puid);
            DApp.bindPot(puid);
        }
    },
    getTVL: async function(){
        DApp.tvl = await DApp.web3.eth.getBalance(DApp.contracts.IRoll.options.address);
        return DApp.toEth(DApp.tvl);
    },
    getPlayerRolls: async function(){
        await DApp.showRollsLoading();
        let options = { filter: { plyr: [DApp.accounts[0]] }, fromBlock: 0, toBlock: 'latest' };
        return await DApp.contracts.IRoll.getPastEvents('Rolls', options).then((results) => {
            DApp.rolls = results; 
            DApp.rollIndex = DApp.rolls.length - 1;
            $("#player-rolls").text(DApp.rolls.length);
            return DApp.bindRoll(DApp.rolls[DApp.rollIndex]);
        }).catch((err) => {
            console.log(err);
        });
    },
    pageRolls: async function (e) {
        e.id.toString().includes('forward') ? DApp.rollIndex++ : DApp.rollIndex--;
        if (DApp.rollIndex >= DApp.rolls.length) DApp.rollIndex = 0;
        if (DApp.rollIndex < 0) DApp.rollIndex = DApp.rolls.length - 1;
        return DApp.bindRoll(DApp.rolls[DApp.rollIndex]);
    },
    getRewards: async function () {
        DApp.rewards = await DApp.contracts.IRoll.methods.getRewards().call({ from: DApp.accounts[0] });
        return DApp.rewards;
    },
    getPlayerInfo: async function () {
        const results = await DApp.contracts.IRoll.methods.getPlayerInfo().call({ from: DApp.accounts[0] });
        DApp.ethBalance = DApp.toEth(results[1]);
        DApp.irollBalance = results[2];
        $("#player-eth").html(DApp.ethBalance);
        $("#player-iroll").html(DApp.irollBalance);
    },    
    getBlockNumber: async function(){
        return DApp.web3.eth.getBlockNumber().then((result) => {
            return result;
        }).catch((err) => {
            console.log(err);
        });
    },
    seedPot: async function(){   
        let uid = $("#pot-uid").text();
        if(uid <= 0){
            return;
        }

        await DApp.contracts.IRoll.methods.seedPot(uid).send({
            from: DApp.accounts[0],
            gas: 1333473,
            value: DApp.web3.utils.toBN(.01 * 10 ** 18)
        })
        .on('receipt', function (receipt) {
            return DApp.bindPot(uid);
        })
        .on('error', function (error, receipt) {
            console.log(error);
            return;
        });
        
    },
    createPot: async function () {
        let wallet = $("#txtLinkWallet").val();
        let entry = DApp.web3.utils.toBN($("#txtEntryFee").val() * 10 ** 18);
        let interval = DApp.web3.utils.toBN($("#txtInterval").val());
        let seed = $("#txtSeed").val();
        let fee = $("#txtFee").val();
        let customRoll = [$("#cr0").val(), $("#cr1").val(), $("#cr2").val(), $("#cr3").val(), $("#cr4").val()];
        
        return true;
    },
    bindResultDice: function (hex) {
        let arr = hex.match(/\d\d/gi).sort();
        for (var i = 0; i < arr.length; i++) {
            const dnum = arr[i];
            const img = '<img src="../img/d-' + parseInt(dnum) + '.png" style="padding-top:12px;width:40px" />';
            const sel = "#di" + (i + 1);
            $(sel).html(img);
            $(".pit-circle").css("background-color", "#BB4100");
        }
    },
    bindPotSearch: function () {
        $('#search-puid').bind("enterKey", function (e) {
            DApp.searchPot();
        });

        $('#search-puid').keyup(function (e) {
            if (e.keyCode == 13) {
                $(this).trigger("enterKey");
            }
        });
    },
    bindRoll: async function (roll) {

        if(roll == null || roll.returnValues == null){
            $("#roll-block").html("<small>NO ROLLS</small>");
            return;
        }

        var rv = roll.returnValues;
        if(rv.puid <= 0){return;}

        const d = DApp.toDice(rv.dice, 15);
        $("#roll-combo").html(DApp.getCombo(rv.reward));
        $("#roll-dice").html(d);
        $("#roll-vrfId").text(rv.vrfid.substring(0, 14) + "..");
        $("#roll-puid").text("# " + rv.puid);
        $("#roll-block").text(roll.blockNumber);
        $("#roll-payout").html(DApp.toEth(rv.payout) + " <small>ETH</small>");
        $("#roll-tokens").html(rv.reward + " <small>IROLL</small>");        
        $("#roll-hash").html(roll.transactionHash.substring(0, 14) + "..");
        return;
    },
    bindPot: async function (puid) {

        const pot = await DApp.getPot(puid);
        
        let d = DApp.toDice(pot.dice, 15);
        $("#pot-dice").html(d);
        $("#pot-header").css("background-color", DApp.getPotColor(puid));
        $("#pot-uid").html("<span style='font-size:1.2em;'>" + pot.UID + "</span>");
        $("#pot-balance").text(DApp.toEth(pot.balance));
        $("#pot-entry").text(DApp.toEth(pot.entry));
        $("#pot-seed").text(pot.seed);
        $("#pot-interval").html(pot.interval + " <small>SECONDS</small>");
        $("#pot-owner").text(pot.owner.substring(0, 14) + "..");

        $("#btn-pot-select").on("click", function(){
            DApp.potSelected = puid;
            DApp.selectPot(puid);
        })
        $("#pot-link").html("<a href='https://iroll.io/?p=" + pot.UID + "iroll.io/?p=" + pot.UID + "</a>");
        
        $("#pot-rwd-jp").html(DApp.rewards[8]);
        $("#pot-rwd-a6").html(DApp.rewards[9]);
        $("#pot-rwd-md").html(DApp.rewards[10]);
        $("#pot-rwd-4k").html(DApp.rewards[7]);
        $("#pot-rwd-ls").html(DApp.rewards[6]);
        $("#pot-rwd-fh").html(DApp.rewards[5]);
        $("#pot-rwd-ss").html(DApp.rewards[4]);
        $("#pot-rwd-3k").html(DApp.rewards[3]);
        $("#pot-rwd-2p").html(DApp.rewards[2]);
        $("#pot-rwd-1p").html(DApp.rewards[1]);
        return;
    },
    bindPotPit: async function () {
        let d = DApp.toDice(DApp.pot.dice, 15);
        $("#pit-pot-dice").html(d);
        $("#hud-center").css("opacity", "100%");
        $("#pit-pot-balance").html(DApp.toEth(DApp.pot.balance) + " <small>$ETH</small>");
        $("#pit-pot-entry").html(DApp.toEth(DApp.pot.entry) + " <small>$ETH</small>");
        $("#pit-pot-uid").html("#" + DApp.pot.UID);
        $("#pot-status").html("AWAITING DICE ROLL");

        $("#button-roll").on("click", () => {
            if(DApp.pot == null){return;}
            DApp.roll();
        });

        
        return;
    },
    toEth: function(wei) {
        let val = Number(DApp.web3.utils.fromWei(DApp.web3.utils.toBN(wei.toString()), "ether"));
        return val.toFixed(5);
    },
    bindPotRolls: function(rolls) {

        if (rolls.length == 0){
            $("#pot-history").html("<br /><br/ ><small>NO ROLL HISTORY</small>");
            return;
        }

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

        for (let i = 0; i < rolls.length; i++) {
            let tr = document.createElement('tr');
            tblBody.appendChild(tr);

            let td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(document.createTextNode(rolls[i].returnValues.player.substring(0, 12) + "."));

            let dice = DApp.toDice(rolls[i].returnValues.dice, 13);
            let div = document.createElement("di");
            div.innerHTML = dice;
            td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(div);

            td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(document.createTextNode(rolls[i].returnValues.reward));

            td = document.createElement("td");
            tr.appendChild(td);
            td.appendChild(document.createTextNode(rolls[i].returnValues.payout));
        }

        $("#pot-history").html(table);

        return;
    },
    getQRCode: async function (puid) {
        $("#pot-qr").html("");
        let potColor = DApp.getPotColor(puid);
        let qr = new QRCode("pot-qr", {
            text: "https://iroll.io/?p=" + pot.UID,
            width: 150,
            height: 150,
            colorDark: potColor,
            colorLight: "#FFFFFF",
            correctLevel: QRCode.CorrectLevel.H
        })
    },
    showRolling: async function () {
        $("#pot-status").text("ROLLING DICE..");
        $("#btn-roll").prop("disabled", true);
        $('div[id^="di"]').html("<i class='fa-solid fa-spinner fa-spin'></i>");
        $(".pit-circle").css("background-color", "#3B673B");
        //$(".fa-th").addClass("fa-spin");
        return;
    },
    showRollFailed: async function (combo) {
        // $("#d1").html("?");
        // $("#d2").html("?");
        // $("#d3").html("?");
        // $("#d4").html("?");
        // $("#d5").html("?");
        $('div[id^="di"]').html("?");
        //$(".fa-th").removeClass("fa-spin");
        $("#btn-roll").prop("disabled", false);
        return;
    },
    showRollComplete: function (combo) {
        $("#pot-status").text("COMPLETE : " + combo);
        //$(".fa-th").removeClass("fa-spin");
        $("#btn-roll").prop("disabled", false);
    },
    showRollsLoading: function(){
        $("#roll-block").html("<i class='fa-solid fa-spinner fa-spin'></i>");
        //$("#roll-combo").text("");
        $("#roll-vrfId").text("");
        $("#roll-puid").text("");
        $("#roll-payout").html("");
        $("#roll-tokens").html("");
        $("#roll-dice").html("");
        //$("#roll-picks").html("");
        $("#roll-hash").html("");
    },
    getPotColor: function(puid){
        let i = (puid % 10) - 1;
        return DApp.colors[i];
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
    toDice: function(hex, w){
        let d = '';
        let arr = hex.match(/\d\d/gi).sort();
         for (var i = 0; i < arr.length; i++) {
             d = d + "<img class='die' src='../img/d-" + parseInt(arr[i]) + ".png' style='width:" + w + "px;' />";
        }
        return d;
    },
    getCombo: function(rwd){
        switch (rwd) {
            case DApp.rewards[1]:
                return "SINGLE PAIR";
            case DApp.rewards[2]:
                return "TWO PAIR";
            case DApp.rewards[3]:
                return "THREE OF A KIND";
            case DApp.rewards[4]:
                return "SMALL STRAIGHT";
            case DApp.rewards[5]:
                return "FULL HOUSE";
            case DApp.rewards[6]:
                return "LARGE STRAIGHT";
            case DApp.rewards[7]:
                return "FOUR OF A KIND";
            case DApp.rewards[8]:
                return "JACKPOT";
            case DApp.rewards[9]:
                return "ALL SIXES";
            case DApp.rewards[10]:
                return "CUSTOM ROLL";
            default:
                return "BUPKIS";
        }
    }
};

