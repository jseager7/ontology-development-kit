### From https://stackoverflow.com/questions/51121875/how-to-run-docker-with-python-and-java
### 1. Get Linux
FROM ubuntu:18.04
LABEL maintainer="obo-tools@googlegroups.com" 

### 2. Get Java, Python and all required system libraries (version control etc)
ENV JAVA_HOME="/usr"
WORKDIR /tools
ENV PATH "/tools/:$PATH"
COPY requirements.txt /tools/
COPY scripts/obodash /tools/
COPY odk/make-release-assets.py /tools/

#ENV JAVA_HOME /usr/lib/jvm/java-8-oracle
# LAYERSIZE ~1000MB
RUN apt-get update &&\
  apt-get install -y software-properties-common &&\
  add-apt-repository ppa:swi-prolog/stable &&\
  apt-get upgrade -y &&\
  apt-get install -y build-essential \
    git \
    openjdk-8-jre \
    openjdk-8-jdk \
    swi-prolog \
    maven \
    python3-pip \
    python3-dev \
    subversion \
    make \
    automake \
    gcc \
    g++ \
    unzip \
    rsync \
    curl \
    wget \
    jq \
    openssl \
    xlsx2csv &&\
    cd /usr/local/bin \
    && ln -s /usr/bin/python3 python \
    && pip3 install --upgrade pip setuptools \
    && pip3 install -r /tools/requirements.txt \
  	&& if [ ! -e /usr/bin/pip ]; then ln -s pip3 /usr/bin/pip ; fi \
  	&& if [[ ! -e /usr/bin/python ]]; then ln -sf /usr/bin/python3 /usr/bin/python; fi \
  	&& rm -r /root/.cache

### 4. Install custom tools
#  scripts/droid



###### owltools & OORT ######
# For now we get these from jenkins builds, but these should be obtained
# by composing existing Dockerfiles, or by obtaining directly from maven
ENV OWLTOOLS 2020-04-06
RUN wget https://github.com/owlcollab/owltools/releases/download/$OWLTOOLS/owltools -O /tools/owltools && \
    wget https://github.com/owlcollab/owltools/releases/download/$OWLTOOLS/ontology-release-runner -O /tools/ontology-release-runner && \
    wget https://github.com/owlcollab/owltools/releases/download/$OWLTOOLS/owltools-oort-all.jar -O /tools/owltools-oort-all.jar && \
    chmod +x /tools/owltools && \
    chmod +x /tools/ontology-release-runner && \
    chmod +x /tools/owltools-oort-all.jar

###### Konclude, the DL reasoner ######
# LAYERSIZE ~28MB
RUN wget https://github.com/konclude/Konclude/releases/download/v0.6.2-845/Konclude-v0.6.2-845-LinuxAlpine-x64-GCC8.3.0-Static-Qt-5.13.zip -O /tools/konclude.zip && \
    unzip /tools/konclude.zip && \
    mv /tools/Konclude-v0.6.2-845-LinuxAlpine-x64-GCC8.3.0-Static-Qt-5.13 /tools/konclude_reasoner && \
    rm /tools/konclude.zip && \
    chmod +x /tools/konclude_reasoner/Binaries && \
    echo "#!/bin/bash" > /tools/Konclude && \
    echo '/tools/konclude_reasoner/Binaries/Konclude $*' >> /tools/Konclude && \
    chmod +x /tools/Konclude

###### ROBOT ######
ENV ROBOT v1.8.1
ARG ROBOT_JAR=https://github.com/ontodev/robot/releases/download/$ROBOT/robot.jar
ENV ROBOT_JAR ${ROBOT_JAR}
# LAYERSIZE ~66MB
RUN wget $ROBOT_JAR -O /tools/robot.jar && \
    wget https://raw.githubusercontent.com/ontodev/robot/$ROBOT/bin/robot -O /tools/robot && \
    chmod +x /tools/robot && \
    chmod +x /tools/robot.jar

# Avoid repeated downloads of script dependencies by mounting the local coursier cache:
# docker run -v $HOME/.coursier/cache/v1:/tools/.coursier-cache ...
ENV COURSIER_CACHE "/tools/.coursier-cache"

###### FASTOBO ######
ENV FASTOBO_VALIDATOR v0.4.0
RUN wget https://dl.bintray.com/fastobo/fastobo-validator/$FASTOBO_VALIDATOR/fastobo_validator-x86_64-linux-musl.tar.gz -O- | tar xzC /tools \
&& chmod +x /tools/fastobo-validator

##### Ammonite #####
# LAYERSIZE ~31MB
RUN (echo "#!/usr/bin/env sh" \
&& curl -L https://github.com/lihaoyi/Ammonite/releases/download/2.0.3/2.13-2.0.3) >/tools/amm \
&& chmod +x /tools/amm
# Force precompile of ammonite files
# LAYERSIZE ~67MB
RUN amm /dev/null

###### DOSDPTOOLS ######
ENV DOSDPVERSION=0.16
ENV PATH "/tools/dosdp-tools/bin:$PATH"
# LAYERSIZE ~200MB
RUN wget -nv https://github.com/INCATools/dosdp-tools/releases/download/v$DOSDPVERSION/dosdp-tools-$DOSDPVERSION.tgz \
&& tar -zxvf dosdp-tools-$DOSDPVERSION.tgz \
&& mv dosdp-tools-$DOSDPVERSION /tools/dosdp-tools \
&& wget --no-check-certificate https://raw.githubusercontent.com/INCATools/dead_simple_owl_design_patterns/master/src/simple_pattern_tester.py -O /tools/simple_pattern_tester.py \
&& chmod +x /tools/dosdp-tools \
&& chmod +x /tools/simple_pattern_tester.py

###### SPARQLProg ######
# See https://github.com/cmungall/sparqlprog/blob/master/INSTALL.md
RUN swipl -g "Opts=[interactive(false)],pack_install(dcgutils,Opts),pack_install(obo_metadata,Opts),pack_install(index_util,Opts),pack_install(regex,Opts),pack_install(typedef,Opts),halt"
RUN swipl -g "pack_install(sparqlprog, [interactive(false)])" -g halt
#RUN swipl -p library=prolog -l tests/tests.pl -g run_tests,halt
ENV PATH "/root/.local/share/swi-prolog/pack/sparqlprog/bin:$PATH"
RUN ln -sf /root/.local/share/swi-prolog/pack/sparqlprog /tools/

RUN cd /tools/ && chmod +x /tools/obodash && git clone --depth 1 --branch docker-dash https://github.com/OBOFoundry/OBO-Dashboard.git && \
    cd OBO-Dashboard && git checkout docker-dash && echo "Dashboard: using branch" &&\
    python3 -m pip install -r requirements.txt && echo " " >> Makefile &&\
    echo "build/robot.jar:" >> Makefile &&\
    echo "	echo 'skipped ROBOT jar download' && touch \$@" >> Makefile && echo "" >> Makefile

########## DROID #########
# LAYERSIZE ~18MB
#RUN apt-get install -y leiningen
#ENV DROID_JAR "droid-0.1.0-SNAPSHOT-standalone.jar"
# LAYERSIZE: ~80MB
#RUN cd /tools/ && mkdir droid_github && cd /tools/droid_github && git clone https://github.com/ontodev/droid &&\
#    cd /tools/droid_github/droid && lein uberjar &&\
#    mv /tools/droid_github/droid/target/uberjar/$DROID_JAR /tools/droid.jar && rm -rf /tools/droid_github &&\
#    ls -l /tools/
#RUN chmod +x /tools/droid

### 5. Install ODK
ARG ODK_VERSION=0.0.0
ENV ODK_VERSION=${ODK_VERSION}

### TODO REVIEW THIS. As we speak, jq is official still stalled at 1.5, but for the walk function, we
### Need 1.6 - once 1.6 is offcial, the following RUN can be removed.
# LAYERSIZE: ~4MB
RUN wget https://github.com/stedolan/jq/releases/download/jq-1.6/jq-linux64 -O /tools/jq && chmod +x /tools/jq

COPY odk/odk.py /tools/
COPY template/ /tools/templates/
RUN chmod +x /tools/*.py
ENV LC_ALL=C.UTF-8
ENV LANG=C.UTF-8

CMD python /tools/odk.py
