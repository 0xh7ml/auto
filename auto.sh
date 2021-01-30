#!/bin/bash
#input domain
domain=$1 

#Passive scan using subenum 

echo "Passive scan starting...."
subfinder -d $domain -o subfinder.txt
assetfinder --subs-only $domain | sort -u > assetfinder.txt
amass enum -passive -norecursive -noalts -d $domain -o amass.txt
findomain --quiet -t $domain -u findomain.txt
cat subfinder.txt assetfinder.txt amass.txt findomain.txt | grep -F ".$domain" | sort -u > passive.txt
rm subfinder.txt assetfinder.txt amass.txt findomain.txt

echo ""
#Active Scan ...

echo "Active scan starting...."
shuffledns -d $domain -w subdomains.txt -r resolvers.txt -o active_tmp.txt
cat active_tmp.txt | grep -F ".$domain" | sed "s/*.//" > active.txt
rm active_tmp.txt
echo ""

#ActivePassive Scan

echo "Collecting Active & Passive Enum Result"
cat active.txt passive.txt | grep -F ".$domain" | sort -u | shuffledns -d $domain -r resolvers.txt -o active_passive.txt
rm active.txt passive.txt

#Permute Scan
if [[ $(cat active_passive.txt | wc -l) -le 50 ]]
then
    echo "[=] Running Dual Permute Enumeration"
    dnsgen active_passive.txt | shuffledns -d $domain -r resolvers.txt -o permute1_tmp.txt
    cat permute1_tmp.txt | grep -F ".$domain" > permute1.txt 
    dnsgen permute1.txt | shuffledns -d $domain -r resolvers.txt -o permute2_tmp.txt
    cat permute2_tmp.txt | grep -F ".$domain" > permute2.txt
    cat permute1.txt permute2.txt | grep -F ".$domain" | sort -u > permute.txt
    rm permute1.txt permute1_tmp.txt permute2.txt permute2_tmp.txt
elif [[ $(cat active_passive.txt | wc -l) -le 100 ]]
then
    echo "[=] Running Single Permute Enumeration"
    dnsgen active_passive.txt | shuffledns -d $domain -r resolvers.txt -o permute_tmp.txt
    cat permute_tmp.txt | grep -F ".$domain" > permute.txt
    rm permute_tmp.txt
else
    echo "[=] No Permutation"
fi

#Final
echo "Collecting Enumerated Final Result"
cat active.txt passive.txt active_passive.txt permute.txt | grep -F ".$domain" | sort -u > sub.txt

#httpx 

echo "httpx running"
httpx -l sub.txt -silent -o sub.httpx
httpx -l sub.txt -csp-probe -silent | grep -F ".$domain" | anew sub.httpx
httpx -l sub.txt -tls-probe -silent | grep -F ".$domain" | anew sub.Httpx

#Outputs
mkdir -p $domain
mv active.txt passive.txt active_passive.txt permute.txt sub.txt sub.httpx $domain
echo ""
echo ""
echo "[#] Total Subdomain Found $(cat sub.txt | wc -l)"
echo "[#] Total HTTP Probed Found $(cat sub.httpx | wc -l)"
