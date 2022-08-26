#!/bin/bash
touch /home/wasimali/test2_ansible/proxy.txt
touch /home/wasimali/test2_ansible/user_input.txt
# Using case for different types of load balancers
case "$1" in

    "click-tracker")
    echo "vn-go-clicktracker-target-proxy" >> /home/wasimali/test2_ansible/proxy.txt
    echo "testing-vn-go-clicktracker-target-proxy" >> /home/wasimali/test2_ansible/proxy.txt
    echo "$1" > /home/wasimali/test2_ansible/user_input.txt
    proxy="vn-go-clicktracker-target-proxy"
    ;;

    "conversion-tracker")
    echo "conv-tracker-target-proxy" > /home/wasimali/test2_ansible/proxy.txt
    echo "$1" > /home/wasimali/test2_ansible/user_input.txt
    proxy="conv-tracker-target-proxy"

    ;;

    "rest-api")
    echo "trackier-api-target-proxy-2" >> /home/wasimali/test2_ansible/proxy.txt
    echo "trackier-api-temp-target-proxy-2" >> /home/wasimali/test2_ansible/proxy.txt
    echo "$1" > /home/wasimali/test2_ansible/user_input.txt
    proxy="trackier-api-target-proxy-2"

    ;;

    "trackier-app")
    echo "testing-trackier-lb-target-proxy-2" > /home/wasimali/test2_ansible/proxy.txt
    echo "$1" > /home/wasimali/test2_ansible/user_input.txt
    proxy="testing-trackier-lb-target-proxy-2"
    ;;

    *)
    echo "No SSL Certs Provided"
    ;;
esac

# Getting ssl cert's from target proxy and store it in a variable.
ssl_cert_list=$(gcloud beta compute target-https-proxies describe $proxy | grep $1 | awk '/sslCertificates/ {print $0}' | cut -d "/" -f 10)

# Using loop to retreive the SAN names of all the SSl cert's defined in our target proxy
for i in ${ssl_cert_list// / }
do
    echo "******** Creating necessary files **************"
    touch /home/wasimali/test2_ansible/f{1..7}.txt
    touch /home/wasimali/test2_ansible/fail_domain.txt
    touch /home/wasimali/test2_ansible/ssl-log.txt
    date >> /home/wasimali/test2_ansible/ssl-log.txt
    echo "$proxy" >> /home/wasimali/test2_ansible/ssl-log.txt

    echo "$i" > /home/wasimali/test2_ansible/f5.txt
    echo "Old cert - $i" >> /home/wasimali/test2_ansible/ssl-log.txt
    # Retreiving SAN names and store it in a variable
    san_name=$(gcloud compute ssl-certificates describe "$i" --format="get(subjectAlternativeNames)")


    trim=$(echo "$san_name" | tr ';' ' ')
    for j in ${trim}
    do
        dig "$j" CNAME | grep -e "vnative" -e "trackier" -e "trperf"  > /dev/null
        if [ $? -eq 0 ]
            then
                echo "$j" >> /home/wasimali/test2_ansible/f6.txt
                dig_domain=$(cat /home/wasimali/test2_ansible/f6.txt | tr '\n' ' ')
            else
                echo -e "\n FAILED $j \n"
                echo "Failed Domains - $j" >> /home/wasimali/test2_ansible/fail_domain.txt
                echo "Failed Domains - $j" >> /home/wasimali/test2_ansible/ssl-log.txt
                echo "Failed Domains - $j" >> /home/wasimali/test2_ansible/f7.txt
        fi
    done

    if [ -s  /home/wasimali/test2_ansible/f7.txt ]
        then
            read -p "Do you  still want to proceed to generate the ssl cert's? (y/n) " yn

    fi
    case $yn in
        y ) echo ok, we will proceed;;
        n ) echo exiting...;
                exit;;

    esac
    domain_name=$(echo "$dig_domain" | cut -d " " -f 1)
    echo "$domain_name"  > /home/wasimali/test2_ansible/f4.txt
    san_list=$(echo "$dig_domain" | cut -d ' ' -f 2-)
    echo "$san_list"
    for k in ${san_list// / }
    do
       # echo $k
        echo "$(cat /home/wasimali/test2_ansible/f1.txt)DNS:$k," > /home/wasimali/test2_ansible/f1.txt
        echo "$k" >> /home/wasimali/test2_ansible/f2.txt
    done
    echo "$(cat /home/wasimali/test2_ansible/f1.txt)" | rev | cut -c 2- | rev > f3.txt
    echo "********************** playbook started *********************************"
    ansible-playbook click-tracker.yml --connection=local -vvvv
    cd /home/wasimali/test2_ansible/ && rm -rf certs account keys csrs
    rm /home/wasimali/test2_ansible/f{1..7}.txt
done
