# Throughput
외부 서버 (or instance끼리)와 패킷을 주고 받을 때의 성능 측정.

동시에 CPU usage를 자세하게 측정.

변경 가능한 옵션
- message size
- CPU core
- memory size
- concurrency(e.g., single TCP stream, 10 concurrent TCP stream)
- scalability(# of instances): 각 instance가 동일한 성능을 보이는지? instance별 성능의 변동폭? 성능의 총 합은 얼마인지?

## Preparation
Local(실험 device)과 server 모두 `netperf` 설치
```
sudo apt install -y netperf
```

Server side에서 `netserver` 실행.

Default port number is 12865.
```
netserver
# netserver -p <port number>

ps aux | grep netserver
```

Client side에서 netserver로 테스트 수행.
```
# netperf -H <server IP> port <port number> -l <test time> -- -m <message size(B)>
netperf -H 192.168.51.232 -l 20 -- -m 64
```

## Script
### Runc
**`runc_throughput.sh`**

`-r`: 필수 옵션. netperf 실험의 반복 횟수. e.g., 10회

`-c`: 컨테이너의 CPU 개수 업데이트. e.g., 라즈베리파이의 경우 1~4

`-m`: 컨테이너의 memory size 업데이트: e.g., 512m, 1G

`-s`: 한 컨테이너 안에서 동시에 실행되는 netperf stream의 개수. e.g., 1, 10

`-n`: 한 host에서 동시에 실행되는 컨테이너의 개수: e.g., 1, 5, 10

한 번에 하나의 옵션만 사용 가능.

### Kata Container
### Firecracker
### Virtual Machine(QEMU/KVM)


## Trouble Shooting
- `Your kernel does not support memory limit capabilities or the cgroup is not mounted. Limitation discarded.`

컨테이너의 memory allocation을 update하려고 하면 오류 발생.
```
sudo vim /boot/firmware/cmdline.txt
# 맨 마지막에 아래 내용 추가. 한 줄에 작성해야 함.
cgroup_enable=memory swapaccount=1
```
