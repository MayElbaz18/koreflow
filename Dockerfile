FROM ubuntu

RUN mkdir /koreflow && chmod 755 /koreflow

RUN apt update &&  apt install -y  git

WORKDIR /koreflow

COPY . /koreflow

RUN chmod  +x ./koreflow.linux

CMD ["./koreflow.linux"]
