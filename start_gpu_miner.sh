#!/usr/bin/env bash
:' Taken from https://unix.stackexchange.com/questions/367584/how-to-adjust-nvidia-gpu-fan-speed-on-a-headless-node
Xorg is started only to set fan speeds etc. with `nvidia-settigns` (which requires X server) and then killed.
'

set -Eeuxo pipefail

# Kill any existing X servers.
# TODO: can we refactor away from sudo?
sudo killall Xorg || true
sudo killall miner || true
sudo killall t-rex || true
sleep 5

# Start a new X server for nvidia-settings to use.
export XDG_SESSION_TYPE=x11
export GDK_BACKEND=x11
export DISPLAY=:0
sudo startx -- $DISPLAY &
sleep 5

# enable persistence mode (https://www.microway.com/hpc-tech-tips/nvidia-smi_control-your-gpus/)
sudo nvidia-smi -pm 1

# Determine the number of GPUs and fans on this machine.
NUM_GPUS=$(sudo nvidia-settings -q gpus | grep -c 'gpu:')
NUM_FANS=$(sudo nvidia-settings -q fans | grep -c 'fan:')

# For each GPU, enable fan control.
for ((i=0; i < NUM_GPUS; i++))
do
    sudo nvidia-settings --verbose=all -a [gpu:$i]/GPUFanControlState=1
    sudo nvidia-settings -a [gpu:$i]/GpuPowerMizerMode=1   # set performance level 1 (high performance), 2 (auto)
    sudo nvidia-smi -i $i -pl 150
    
    # lock core clock (https://github.com/NebuTech/NBMiner/issues/553)
    sudo nvidia-smi -i $i -lgc 1350
    
    # Mem overclock
    # Should also work, but we already use 'GPUMemoryTransferRateOffsetAllPerformanceLevels'
    #sudo nvidia-smi -i $i -lmc 7850
    sudo nvidia-settings -a [gpu:$i]/GPUMemoryTransferRateOffsetAllPerformanceLevels=1800
done

# For each fan, set fan speed to 100%.
for ((i=0; i < NUM_FANS; i++))
do
    sudo nvidia-settings --verbose=all -a [fan:$i]/GPUTargetFanSpeed=100
done

# Kill the X server that we started.
sudo killall Xorg || true
sleep 5

# start miner
#sudo ./gpu/gminer/miner --algo ethash --server eth-de.flexpool.io:5555 --ssl 1 --user $WALLET_ETH.$(hostname) -p x --lhr_autotune 1 1 1 --lock_cclock 1400 1400 1400
#sudo -b ./gpu/trex/t-rex --algo ethash -o stratum+ssl://eth-de.flexpool.io:5555 --user $WALLET_ETH.$(hostname) -p x --no-new-block-info --send-stales --lhr-autotune-mode full --temperature-limit 80 --lock-cclock 1400,1400,1400 --dag-build-mode 2 --lhr-autotune-step-size 0.1 --log-path /home/toaster/workspace/mining/start_gpu_miner.log &>/dev/null
sudo -b ./gpu/nbminer/NBMiner_Linux/nbminer -a ethash -o stratum+ssl://eth-de.flexpool.io:5555 -u $WALLET_ETH.$(hostname) -p x --platform 1 --fee 0 --log-file /home/user/workspace/mining/start_gpu_miner.log &>/dev/null
