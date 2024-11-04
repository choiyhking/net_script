# Throughput
외부 서버(or instance끼리)로 TCP/UDP 패킷을 주고 받을 때의 성능

동시에 CPU usage를 자세하게 측정(user, sys, softirq, guest)

변경 가능한 옵션

- message size
- CPU core
- memory size
- concurrency(e.g., single TCP stream, 10 concurrent TCP stream)
- scalability(# of instances): 
각 instance가 동일한 성능을 보이는지? instance별 성능의 변동폭? 성능의 총 합은 얼마인지?

## Preparation
Local(실험할 device)과 server 모두에 netperf 설치
```
sudo apt install -y netperf
```

Server side에서 netserver 실행.

Default port number is 12865.
```
netserver
# netserver -p <port number>

ps aux | grep netserver
```

Client side에서 netserver로 테스트 실험 수행.
```
# netperf -H <server IP> port <port number> -l <test time> -- -m <message size(B)>
netperf -H 192.168.51.232 -l 20 -- -m 64
```

## Script
### RunC

### Kata Container
### Firecracker
### Virtual Machine(QEMU/KVM)


## TroubleShooting
- `Your kernel does not support memory limit capabilities or the cgroup is not mounted. Limitation discarded.`

컨테이너의 memory allocation을 update하려고 하면 오류 발생.
```
sudo vim /boot/firmware/cmdline.txt
cgroup_enable=memory swapaccount=1
```
