document.addEventListener('DOMContentLoaded', onDocumentLoad);
//INIT DAPP
function onDocumentLoad() {
    DApp.init();
}

const DApp = {
    web3: null,
    contracts: {},
    accounts: [],
    initd: false,
    
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
                console.log(data.networks[5777].address);
                if (!data.networks[netId]) {
                    console.log("contract not found on network");
                    return;
                }            
                DApp.contracts.IRoll = new DApp.web3.eth.Contract(data.abi, data.networks[netId].address);
            }); 
        }catch(error){
            console.log(error);
        }
        return;
    },
    getContractJSON: async function (src) {
        return $.getJSON(src).then(function (data) {
            return data;
        });
    },
};