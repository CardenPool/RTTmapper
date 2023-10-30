# RTTmapper
This is a small script made available for all Cardano's Stake Pool Operators (SPO). Its main purpose is to **provide network information** useful to build up a good static topology file, by hands. Pending the launch of P2P, this SH script can be a valuable support for **managing and optimizing the network performance** of your stake pool.

## About
<img src="https://www.cardenpool.org/wp-content/uploads/2021/12/mesh_topology.gif" align="right" width="30%">
This script downloads the latest Cardano's relays list from Cardano Scanner and measure the Round Trip Times (RTT) for each relay (peer). To verify the geo information provided by Cardano Scanner, a further geo-location of the XX best RTT machines is done. The output list is saved to a CSV file. This can be imported within an excel file to filter data and cherry picking the relays with the best RTT for each continent/country with the aim to build up a good performing mainnet-topology.json file. A good performing topology file, maximize the blocks propagation time and helps to compete in slot battles. Before use this script, please fully undestand how the Cardano's topology works, what "blocks propagation" is and why RTT can be crucial in a slot height battle.




## Example output
This picture shows the RTT from Milan to relays belonging to the Africa country (selected by the script configuration). The script order the relays (from smaller to bigger RTT) and generates output textual files.
![RTT IT AF](https://github.com/CardenPool/RTTmapper/assets/86101039/2b615521-5587-457c-8d6f-61327ff86203)

Thanks to [Martin Lang](https://github.com/gitmachtl/scripts) for providing the base code on which this script was built.

## Installation
#### Install the script
```shell
#Pull the script from GitHub
mkdir -p $HOME/RTTmapper/ && cd $_
git clone https://github.com/CardenPool/RTTmapper.git $HOME/RTTmapper

#Give execution rights
cd $HOME/RTTmapper
chmod +x RTTmapper.sh
```
#### Run the script
```shell
#Edit the script and set the target "CONTINENT" country code
nano RTTmapper.sh
```
```shell
#Run the script to map the given country
./RTTmapper.sh
#Suggestion: To build a complete list, iterate the edit and run phase for each country  
```
#### Update to latest release
```shell
git pull origin main
```
#### Check Git status
```shell
git status
```

## Contacts
* Website - https://www.cardenpool.org
* Twitter - [@Carden_Pool](https://twitter.com/Carden_Pool)
* Email - info@cardenpool.org
* Telegram Group - [@cardenpool](https://t.me/cardenpool)
