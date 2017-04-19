FROM dockershelf/latex:sid
LABEL maintainer "cascaval@barefootnetworks.com"

RUN apt-get update && apt-get install -y nodejs npm make
RUN npm install madoko -g
RUN apt-get install -y texlive-generic-extra texlive-science texlive-xetex dvipng
RUN ln -s /usr/bin/nodejs /usr/bin/node
VOLUME ["/usr/src/p4-spec"]
WORKDIR /usr/src/p4-spec
