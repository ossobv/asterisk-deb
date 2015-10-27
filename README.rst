OSSO build of Asterisk packages for Debian
==========================================

This is the ``debian/`` dir you need to create Debian (or Ubuntu)
packages of the latest `Asterisk PBX <http://www.asterisk.org/>`_.

Place it inside the extracted Asterisk tarball and to create the
necessary ``*.deb`` files. See detailed instructions below.

Much thanks to the Debian team for creating the initial files and
sharing them! The starting point for for this ``debian/`` dir is
taken from the `Debian AnonSCM repository
<http://anonscm.debian.org/cgit/pkg-voip/asterisk.git>`_.

If you're happy with these files without any additional changes,
you can get precompiled binary packages from the *OSSO ppa*
directly. See `Using the OSSO ppa <#user-content-using-the-osso-ppa>`_.



Setting up a build environment
------------------------------

Installing build prerequisites:

.. code-block:: console

    # apt-get install debhelper dpkg-dev quilt build-essential

Installing build dependencies (11-jessie):

.. code-block:: console

    # apt-get install libncurses5-dev libjansson-dev libxml2-dev \
        libsqlite3-dev libreadline-dev unixodbc-dev libmysqlclient-dev
    # apt-get install corosync-dev libcurl4-openssl-dev \
        libgsm1-dev libtonezone-dev libasound2-dev libpq-dev \
        libbluetooth-dev autoconf libnewt-dev libsqlite0-dev \
        libspeex-dev libspeexdsp-dev libpopt-dev libiksemel-dev \
        freetds-dev libvorbis-dev libsnmp-dev libc-client2007e-dev \
        libgmime-2.6-dev libjack-dev libcap-dev libopenr2-dev \
        libresample1-dev libneon27-dev libical-dev libsrtp0-dev \
        libedit-dev
    # apt-get install libpjproject-dev

Ensure that you have a sane ``.quiltrc`` so you can test the quilt patches.

.. code-block:: console

    $ cat >~/.quiltrc <<EOF
    QUILT_PATCHES=debian/patches
    QUILT_NO_DIFF_INDEX=1
    QUILT_NO_DIFF_TIMESTAMPS=1
    QUILT_REFRESH_ARGS="-p ab --no-timestamps --no-index"
    QUILT_DIFF_OPTS="--show-c-function"
    EOF



Preparing an Asterisk build
---------------------------

Fetching the latest Asterisk, creating a local scratchpad repository and
moving this directory to the ``debian/`` dir.

.. code-block:: console

    $ VERSION=11.20.0
    $ wget "http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-${VERSION}.tar.gz" \
        -O "asterisk_${VERSION}.orig.tar.gz"
    $ tar zxf "asterisk_${VERSION}.orig.tar.gz"

    $ cd asterisk-${VERSION}
    $ git init
    $ git add -fA   # adds all files, even the .gitignored ones
    $ git commit -m "clean ${VERSION}"

    $ mv ~/asterdeb-osso.git debian

Test that all patches apply:

.. code-block:: console

    $ cd debian
    $ quilt push -a

Refreshing the quilt patches (optional). By altering the ``'Now at patch'``
needle you can refresh from a certain patch (your own?) and onwards.

.. code-block:: console

     $ quilt pop -a; \
         until quilt push | grep 'Now at patch'; do true; done; \
         quilt pop; while quilt push; do quilt refresh; done



Compiling the Asterisk packages
-------------------------------

After preparing the build, there is nothing more to do except run
``dpkg-buildpackage`` and wait.

Before this step, you can add/edit your own patches. See
`Quilting and patching_` below.
Don't forget to update the ``changelog`` if you change anything.

.. code-block:: console

    $ #vim debian/changelog
    $ DEB_BUILD_OPTIONS=parallel=6 dpkg-buildpackage -us -uc



Quilting and patching
---------------------

If you want to add/change source, you can append to the Debian quilt patches.

You'll want to test this on a locally compiled build, without packaging it
for every change. Set up your build like this:

.. code-block:: console

    $ git clone https://github.com/asterisk/asterisk asterisk.git
    $ # or: http://gerrit.asterisk.org/asterisk
    $ cd asterisk.git
    $ git fetch --all   # make sure we also fetch all tags
    $ mv ~/asterdeb-osso.git debian

Select the version. Depending on what you previously did, you'll need only some
of these. Consult your local source of git knowledge for more information.

.. code-block:: console

    $ git reset         # unstages staged changes
    $ git checkout .    # drops all changes
    $ rm -rf .pc        # drop local quilt bookkeeping
    $ rm -rf addons/mp3     # drop downloaded mp3 sources
    $ git clean -xf     # removes all excess files

    $ VERSION=11.20.0
    $ git checkout -b local-${VERSION} ${VERSION}   # branch tag 11.20.0 onto local-11.20.0

First, you have to patch all of the Debian changes.

.. code-block:: console

    $ quilt push -a
    $ git commit -m "asterdeb-osso quilted"

Now you can start changing stuff, compiling, installing. Et cetera.

When you're happy with the result, you write the changes to a Debian patch file:

.. code-block:: console

    $ git diff > debian/patches/my-awesome-changes.patch
    $ echo my-awesome-changes.patch >> debian/patches/series
    $ git checkout .    # drop the local changes
    $ quilt push        # reapply the changes, using quilt

For bonus points, you'll edit your newly generated ``debian/patches/my-awesome-changes.patch``
and add appropriate header values as described in
`DEP3, Patch Tagging Guidelines <http://dep.debian.net/deps/dep3/>`_.

Store your updated patches in your own repository, and rebase your changes
against changes in ``asterdeb-osso``.



Installing and configuring
--------------------------

See ``INSTALL.rst`` in this directory for tips on how to install it.



Using the OSSO ppa
------------------

If you're happy with these files without any additional changes,
you can fetch precompiled binary packages from the OSSO ppa if you like.

USE IT AT YOUR OWN RISK. OSSO DOES NOT GUARANTEE AVAILABILITY OF THE SERVER.
OSSO DOES NOT GUARANTEE THAT THE FILES ARE SANE.

.. code-block:: console

    $ sudo sh -c 'cat >/etc/apt/sources.list.d/osso-ppa-osso.list' <<EOF
    deb http://ppa.osso.nl/debian jessie osso
    deb-src http://ppa.osso.nl/debian jessie osso
    EOF
    $ wget -qO- https://ppa.osso.nl/support+ppa@osso.nl.gpg | sudo apt-key add -
    $ sudo apt-get update
    $ sudo apt-get install asterisk


/Walter Doekes <wjdoekes+asterdeb@osso.nl>  Tue, 27 Oct 2015 15:15:54 +0100
