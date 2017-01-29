#!/usr/bin/env bash

send () {
  tmux send-keys -t $1 "$2" Enter
}

status () {
  tmux set -g window-status-current-format "$1"
}

tmux set -g status-position top

ETHEREUMCLI="docker exec -i ethereum geth --verbosity 0"

status "initializing"

sleep 3

status "starting ethereum node"
send 1 "docker run -d --name ethereum -v ${PWD}/ethash:/root/.ethash -v ${PWD}/ethereum:/root/.ethereum -v ${PWD}/js:/root/.js -p 8545:8545 -p 30303:30303 lwieske/ethereumcore:geth-1.5 --dev --rpc --rpcaddr 0.0.0.0"
sleep 3

status "creating genesis block"
send 1 "docker exec -i ethereum geth --verbosity 3 init /root/.ethereum/genesis.json"
sleep 3

status "creating proof of work dag"
send 1 "docker exec -i ethereum geth --verbosity 3 makedag 3000 /root/.ethash"
sleep 3

status "mining & logging"
send 1 "docker exec -i ethereum geth -verbosity 3 --mine"

status "getting balances / as setup"

sleep 3

send 0 "${ETHEREUMCLI} attach"
sleep 3
send 0 "web3.fromWei(eth.getBalance(eth.accounts[0]),'ether')"
sleep 1
send 0 "web3.fromWei(eth.getBalance(eth.accounts[1]),'ether')"
sleep 1
send 0 "web3.fromWei(eth.getBalance(eth.accounts[2]),'ether')"
sleep 1

status "mining to ten blocks"

while (( $(${ETHEREUMCLI} --exec "web3.eth.blockNumber" attach) <= 10 ));do sleep 5; done

status "prepare contract transaction"

send 0 "personal.unlockAccount(eth.accounts[0], 'jm032017', 60)"
sleep 3
send 0 "eth.getCompilers()"
sleep 1

status "define/compile/mine contract transaction"

send 0 "loadScript('/root/.js/tokencontract.js')"

sleep 30

status "execute contract"

send 0 "token.coinBalanceOf(eth.accounts[0]) + ' tokens'"
sleep 3
send 0 "token.sendCoin.sendTransaction(eth.accounts[1], 1000, {from: eth.accounts[0]})"

sleep 30

send 0 "token.coinBalanceOf.call(eth.accounts[0]) + ' tokens'"
sleep 3
send 0 "token.coinBalanceOf.call(eth.accounts[1]) + ' tokens'"

sleep 10

send 0 "exit"

status "mining to thirty blocks"

while (( $(${ETHEREUMCLI} --exec "web3.eth.blockNumber" attach) <= 20 ));do sleep 1; done
ps -ef | grep mine | awk '{print $2}' | xargs kill -9

(docker stop ethereum ; docker rm ethereum) &>/dev/null

send 0 "exit"

send 0 "exit"
