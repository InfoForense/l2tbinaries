#!/bin/bash
#
# Script to set up tests on Travis CI.

# Exit on error.
set -e;

if test -n "${FEDORA_VERSION}";
then
	CONTAINER_NAME="fedora${FEDORA_VERSION}";
	CONTAINER_OPTIONS="-e LANG=C.utf8";

	docker pull registry.fedoraproject.org/fedora:${FEDORA_VERSION};

	docker run --name=${CONTAINER_NAME} --detach -i registry.fedoraproject.org/fedora:${FEDORA_VERSION};

	docker exec ${CONTAINER_NAME} dnf install -y dnf-plugins-core langpacks-en;

	TRACK=${TRAVIS_BRANCH/master/stable};

	docker exec ${CONTAINER_NAME} dnf copr -y enable @gift/${TRACK};

	# Install packages.
	RPM_PACKAGES="git python3";

	if test "${TARGET}" != "gitsource";
	then
		RPM_PACKAGES="${RPM_PACKAGES} python3-plaso plaso-tools";
	fi
	docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} dnf install -y ${RPM_PACKAGES};

elif test -n "${UBUNTU_VERSION}";
then
	CONTAINER_NAME="ubuntu${UBUNTU_VERSION}";

	docker pull ubuntu:${UBUNTU_VERSION};

	docker run --name=${CONTAINER_NAME} --detach -i ubuntu:${UBUNTU_VERSION};

	# Install add-apt-repository and locale-gen.
	docker exec -e "DEBIAN_FRONTEND=noninteractive" ${CONTAINER_NAME} sh -c "apt-get update -q";
	docker exec -e "DEBIAN_FRONTEND=noninteractive" ${CONTAINER_NAME} sh -c "apt-get install -y libterm-readline-gnu-perl locales software-properties-common";

	if test "${TARGET}" = "pylint3";
	then
		docker exec ${CONTAINER_NAME} add-apt-repository ppa:gift/pylint3 -y;
	else
		TRACK=${TRAVIS_BRANCH/master/stable};

		docker exec ${CONTAINER_NAME} add-apt-repository ppa:gift/${TRACK} -y;
	fi
	docker exec -e "DEBIAN_FRONTEND=noninteractive" ${CONTAINER_NAME} sh -c "apt-get update -q";

	# Set locale to US English and UTF-8.
	docker exec ${CONTAINER_NAME} locale-gen en_US.UTF-8;

	# Set time zone to UTC.
	docker exec ${CONTAINER_NAME} ln -f -s /usr/share/zoneinfo/UTC /etc/localtime;

	# Install packages.
	if test "${TARGET}" = "pylint3";
	then
		DPKG_PACKAGES="git pylint";
	else
		DPKG_PACKAGES="git python3";

		if test "${TARGET}" = "gitsource";
		then
			DPKG_PACKAGES="${DPKG_PACKAGES} pylint sudo";
		else
			if test ${TRAVIS_BRANCH} != "master";
			then
				# Currently there is no Timesketch in GIFT PPA stable yet.
				DPKG_PACKAGES="${DPKG_PACKAGES} python3-timesketch";
			fi
			DPKG_PACKAGES="${DPKG_PACKAGES} docker-explorer-tools python3-plaso plaso-tools sleuthkit";
		fi
	fi
	echo "apt-get install -y ${DPKG_PACKAGES}";
	docker exec -e "DEBIAN_FRONTEND=noninteractive" ${CONTAINER_NAME} sh -c "apt-get install -y ${DPKG_PACKAGES}";

elif test ${TARGET} = "dockerhub";
then
	docker pull "log2timeline/plaso";

elif test ${TRAVIS_OS_NAME} = "osx";
then
	brew update;

	# Brew will exit with 1 and print some diagnotisic information
	# to prevent the CI test from failing || true is added.
	brew install tox || true;
fi
