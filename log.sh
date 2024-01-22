#!/bin/sh
REGISTRY_FILE="/mnt/flash/system/.registry"
tempEX="/tmp/tempEX"
tempDT="/tmp/tempDT"
tempLOG="/tmp/tempLOG"
tempOUT="/tmp/tempOut.txt"
output="/tmp/output.txt"
newlogs="/tmp/new_logs.txt"
OID1=".1.3.6.1.4.1.89.82.2.9.1.2" # date time
OID2=".1.3.6.1.4.1.89.82.2.9.1.6" # logs
OID3=".1.3.6.1.4.1.89.82.2.9.1.7" # extra logs
commString="public"
targetHost="203.0.113.121"
SR_NO=$(grep '0x1004' "$REGISTRY_FILE" 2>/dev/null | cut -d'=' -f2 | tr -d ' .<>*\\/\t')

# Checking wether switch is connected to rudder or not
cloud_conn="/mnt/flash/sw-config.json"                                                                                                                                       
while [ "$(jq -r '.wizard.miyagi_cloud_conn' "$cloud_conn") == "false" ]; do                                                                                                                                                                                             
    sleep 5                                                                                                                                                                                                                                                                                                         
done    

# snmpwalk fucntion
walksnmp() {
    filename="$1"
    snmpwalk -v2c -c "$commString" "$targetHost" "$OID1" | awk -F "STRING: " '{gsub(/"/,""); print $2}' >"$tempDT"
    snmpwalk -v2c -c "$commString" "$targetHost" "$OID2" | awk -F "STRING: " '{gsub(/"/,""); print $2}' | awk 'BEGIN { RS="\n\n" } { gsub(/\n\n/," "); print $0 }' >"$tempLOG"
    snmpwalk -v2c -c "$commString" "$targetHost" "$OID3" | awk -F "STRING: " '{gsub(/"/,""); print $2}' | awk 'BEGIN { RS="\n\n" } { gsub(/\n\n/," "); print $0 }' >"$tempEX"
    awk '{ if ((getline dt < ARGV[2]) > 0 && (getline ex < ARGV[3]) > 0) print $0 dt ex }' "$tempDT" "$tempLOG" "$tempEX" >"$filename"
    cd /tmp/
    rm "$tempDT" "$tempLOG" "$tempEX"
}

# Send Initial Logs
walksnmp "$tempOUT"
generate_json() {
    JSONDATA=$(
        jq --null-input \
        --arg sr_no "$SR_NO" \
        --arg data "$1" \
        '{"sr_no": $sr_no, "data": $data}'
    )
    echo "$JSONDATA"
}

FIRST_LOGS=$(cat "$tempOUT")
FIRST_DATA=$(generate_json "$FIRST_LOGS")
while true; do
    exec /usr/bin/publish "$FIRST_DATA" &
    wait $!
    if [ $? -eq 0 ]; then
        echo "[$(date "+%d-%b-%Y %H:%M:%S")] Initial Logs sent."
        break
    else
        sleep 1
    fi
done

# Loop to keep checking for new logs
while true; do

    walksnmp "$output"
    grep -Fxv -f "$tempOUT" "$output" | awk '{print $0}' >"$newlogs"
    if [ -s "$newlogs" ]; then
        LOGS=$(cat "$newlogs")
        MYDATA=$(generate_json "$LOGS")
        while true; do
            exec /usr/bin/publish "$MYDATA" &
            wait $!
            if [ $? -eq 0 ]; then
                echo "[$(date "+%d-%b-%Y %H:%M:%S")] Updated logs sent."
                break
            else
                sleep 1
            fi
        done
    fi

    cd /tmp/	
    cp "$output" "$tempOUT"
    sleep 10
done
