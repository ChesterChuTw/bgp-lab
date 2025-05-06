FROM ubuntu:20.04

RUN apt update && \
    DEBIAN_FRONTEND=noninteractive apt install -y frr frr-pythontools iproute2 iputils-ping && \
    apt clean

CMD ["/bin/bash"]
