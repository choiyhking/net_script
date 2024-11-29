# (1) Basic
## Data Transmission Experiment (TCP_STREAM)
- netperf: 외부 서버로 패킷을 보낼 때의 성능 측정.
  - `throughput(Mbps)`
- pidstat: process CPU usage를 자세하게 측정.
  - `%usr`, `%system`, `%guest`, `%wait`, `%CPU`
- mpstat: host 전체 CPU usage를 자세하게 측정.
  - `%usr`, `%system`, `%iowait`, `%irq`, `%soft`, `%steal`, `%guest`, `%ideal`
- perfstat: process의 다양한 low-level 지표 측정.
  - `CPU cycles`, `instructions`, `cache-misses`, `page-faults`, `context-switches`

**변경 가능한 옵션**
- message size
- CPU core
- memory size
- concurrency (e.g., single TCP stream, 10 concurrent TCP stream)
- scalability (# of instances)

### \<platform\>_tx.sh

`-r`: 필수 옵션. netperf 실험의 반복 횟수. e.g., 10회

`-c`: 컨테이너의 CPU 개수 업데이트. e.g., 라즈베리파이의 경우 1~4

`-m`: 컨테이너의 memory size 업데이트: e.g., 512m, 1G

`-s`: 한 컨테이너 안에서 동시에 실행되는 netperf stream의 개수. e.g., 1, 10

`-n`: 한 host에서 동시에 실행되는 컨테이너의 개수: e.g., 1, 5, 10

한 번에 하나의 옵션만 사용 가능.

## Request/Response Experiment (TCP_RR)
- netperf: 외부 서버와 request-response transaction rate를 측정.
  - `throughput(trans/s)`, `min_latency(us)`, `max_latency(us)`, `mean_latency(us)`, `stddev_latency(us)`

**변경 가능한 옵션**
- request size
- response size

### \<platform\>_rr.sh

`-r`: 필수 옵션. netperf 실험의 반복 횟수. e.g., 10회


# (2) Performance Interference
TBD

# (3) Single Application
TBD

# (4) Microservice
TBD

# TroubleShooting
**[Error #1] 컨테이너의 memory allocation을 update하려고 하면 오류 발생**
- `Your kernel does not support memory limit capabilities or the cgroup is not mounted. Limitation discarded.`

```
sudo vim /boot/firmware/cmdline.txt
# 맨 마지막에 아래 내용 추가. 한 줄에 작성해야 함.
cgroup_enable=memory swapaccount=1
```
