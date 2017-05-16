FROM dockershelf/latex:sid
LABEL maintainer "cascaval@barefootnetworks.com"

RUN apt-get update && apt-get install -y nodejs npm make
RUN npm install madoko -g
RUN apt-get install -y texlive-generic-extra texlive-science texlive-xetex dvipng
RUN ln -s /usr/bin/nodejs /usr/bin/node
VOLUME ["/usr/src/p4-spec"]
WORKDIR /usr/src/p4-spec

# add extra fonts for P4_14 look-alike
RUN apt-get update --fix-missing
RUN mkdir -p /usr/share/fonts/truetype/UtopiaStd /usr/share/fonts/truetype/LuxiMono
COPY UtopiaStd-Regular.otf /usr/share/fonts/truetype/UtopiaStd/
COPY luximr.ttf /usr/share/fonts/truetype/LuxiMono/
RUN apt-get install -y texlive-math-extra fontconfig git
COPY fix_helvetica.conf /etc/fonts/local.conf
RUN fc-cache -fv
