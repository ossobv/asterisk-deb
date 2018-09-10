FROM debian:stretch
# FROM $(os):$(oscodename)
MAINTAINER Walter Doekes <wjdoekes+asterisk-deb@osso.nl>

ARG osdistshort=deb
ARG oscodename=stretch
ARG upname=asterisk
ARG upversion=11.25.3
ARG debepoch=1:
ARG debversion=0osso1

ENV DEBIAN_FRONTEND noninteractive

# This time no "keeping the build small". We only use this container for
# building/testing and not for running, so we can keep files like apt
# cache.
RUN echo 'APT::Install-Recommends "0";' >/etc/apt/apt.conf.d/01norecommends
#RUN sed -i -e 's:security.ubuntu.com:APTCACHE:;s:archive.ubuntu.com:APTCACHE:' /etc/apt/sources.list
#RUN printf 'deb http://PPA/ubuntu xenial COMPONENT\n\
#deb-src http://PPA/ubuntu xenial COMPONENT\r\n' >/etc/apt/sources.list.d/osso-ppa.list
#RUN apt-key adv --keyserver pgp.mit.edu --recv-keys 0xBEAD51B6B36530F5
RUN apt-get update -q
RUN apt-get install -y apt-utils
RUN apt-get dist-upgrade -y
RUN apt-get install -y \
    bzip2 ca-certificates curl git \
    build-essential dh-autoreconf devscripts dpkg-dev equivs quilt

# Copy debian dir, check version
RUN mkdir -p /build/debian
COPY debian/changelog /build/debian/changelog
RUN . /etc/os-release && \
    fullversion="${upversion}-${debversion}+${osdistshort}${VERSION_ID}" && \
    expected="${upname} (${debepoch}${fullversion}) ${oscodename}; urgency=medium" && \
    head -n1 /build/debian/changelog && \
    if test "$(head -n1 /build/debian/changelog)" != "${expected}"; \
    then echo "${expected}  <-- mismatch" >&2; false; fi

# Set up upstream source, move debian dir and jump into dir.
#
# Trick to allow caching of asterisk*.tar.gz files. Download them
# once using the curl command below into .cache/* if you want. The COPY
# is made conditional by the "[2]" "wildcard". (We need one existing
# file (README.rst) so the COPY doesn't fail.)
COPY README.rst .cache/${upname}_${upversion}.orig.tar.g[z] /build/
RUN test -s /build/${upname}_${upversion}.orig.tar.gz || \
    curl --fail "http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/${upname}-${upversion}.tar.gz" \
    >/build/${upname}_${upversion}.orig.tar.gz
RUN cd /build && tar zxf "${upname}_${upversion}.orig.tar.gz" && \
    mv debian "${upname}-${upversion}/"
WORKDIR "/build/${upname}-${upversion}"

# Apt-get prerequisites according to control file.
COPY debian/compat debian/control debian/
RUN mk-build-deps --install --remove --tool "apt-get -y" debian/control

# Hacks to fix d-shlibs problems, which are fixed in stretch/bionic.
#COPY d-shlibs.patch /build/
#RUN patch -p0 --directory=/ </build/d-shlibs.patch && apt-get update

# Build!
COPY debian debian
RUN DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc -sa

# Sanity checks.
RUN echo "Install checks:" && cd .. && . /etc/os-release && \
     fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
     apt-get install -y asterisk-core-sounds-en && \
     dpkg -i \
       asterisk_${fullversion}_*.deb \
       asterisk-config_${fullversion}_*.deb  \
       asterisk-dbg_${fullversion}_*.deb \
       asterisk-modules_${fullversion}_*.deb
RUN asterisk -V | grep -F "${upversion}" && asterisk -V | grep -F "${debversion}"
RUN echo "Linker checks:" && \
    ldd /usr/lib/asterisk/modules/res_rtp_asterisk.so | grep libpj
# Check that we're not using both openssl 1.0 and 1.1
RUN find /build/asterisk-${upversion}/debian/tmp -name '*.so' -o -name asterisk -type f | \
    sort | while read f; do if ldd "$f" | grep -qF libssl.so.1.1; then \
    echo "$f: linked against openssl 1.1, may cause trouble" >&2; fi; done

# Write output files (store build args in ENV first).
ENV oscodename=$oscodename osdistshort=$osdistshort \
    upname=$upname upversion=$upversion debversion=$debversion
CMD . /etc/os-release && fullversion=${upversion}-${debversion}+${osdistshort}${VERSION_ID} && \
    if ! test -d /dist; then echo "Please mount ./dist for output" >&2; false; fi && \
    echo && . /etc/os-release && mkdir /dist/${oscodename}/${upname}_${fullversion} && \
    mv /build/*${fullversion}* /dist/${oscodename}/${upname}_${fullversion}/ && \
    mv /build/${upname}_${upversion}.orig.tar.gz /dist/${oscodename}/${upname}_${fullversion}/ && \
    chown -R ${UID}:root /dist/${oscodename} && \
    cd / && find dist/${oscodename}/${upname}_${fullversion} -type f && \
    echo && echo 'Output files created succesfully'
