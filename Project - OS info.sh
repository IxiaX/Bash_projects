# Purpose: Displays local machine details: OS, IP, Memory usage and processes details
# INTENDED OS: Linux based

#!/bin/bash

echo

# Get Linux Details
Lin_dist=$(cat /etc/os-release | grep -w NAME= | tr ' ' '_' | tr '"' ' ' | awk '{print $NF}' | tr '_' ' ')
Lin_Ver=$(cat /etc/os-release | grep -w VERSION= | tr '"' ' ' | awk '{print $NF}')

# Display OS details
echo "OS DETAILS: $Lin_dist (Ver $Lin_Ver)"
echo

# Get public IP details
pub_ip=$( curl -s ifconfig.co )
dgate=$( route | grep UG | awk '{print $2}' | head -n 1 )
prv_ip=$( ifconfig | grep broadcast | awk '{print $2}' | head -n 1)

# Display local details
echo IP DETAILS
echo Private IP: $prv_ip
echo Public IP: $pub_ip
echo Default Gateway: $dgate
read -p "press enter to continue..."
echo

# Display disk usage details
echo HARD DISK DETAILS
echo -e "Total\tUsed\tFree"
df -H | grep -w / | awk '{print $(NF-4)"\t"$(NF-3)"\t"$(NF-2)}'
read -p "press enter to continue..."
echo

# gets high level directory to be removed later and stores it into tmp file
hi_lvl_dir=$(df | grep -v Used | grep -vw /  | awk '{print $3"\t\t"$6}' | sort -n | tail -n 1 | awk '{print $NF}')
sudo du $hi_lvl_dir > tmp

# displays memory usage after filtering high level directory
echo MEMORY USAGE DETAILS
echo Your top 5 directories:
echo -e "Used Space \t Directory"
echo $hi_lvl_dir
cat tmp | sort -n | grep $hi_lvl_dir/ | tail -n 5 | awk '{print $1"\t\t"$2}'

# removes tmp file created earlier
rm tmp
read -p "press enter to continue..."
echo

# Display linux processes
top -id 10





