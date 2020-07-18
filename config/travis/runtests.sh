#!/bin/bash
#
# Script to run tests on Travis CI.

# Exit on error.
set -e;

if test -n "${FEDORA_VERSION}";
then
	CONTAINER_NAME="fedora${FEDORA_VERSION}";
	CONTAINER_OPTIONS="-e LANG=C.utf8";

	docker exec ${CONTAINER_NAME} sh -c "git clone https://github.com/log2timeline/plaso.git";

	# TODO: remove after troubleshooting issue with file system encoding.
	docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "python3 -c 'import sys; print(sys.getfilesystemencoding())'";

	docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && python3 /usr/bin/log2timeline.py --status_view linear test.plaso test_data/image.qcow2";

	docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && python3 /usr/bin/psort.py --status_view linear -w timeline.log test.plaso";

elif test -n "${UBUNTU_VERSION}";
then
	CONTAINER_NAME="ubuntu${UBUNTU_VERSION}";
	CONTAINER_OPTIONS="-e LANG=en_US.UTF-8";

	if test "${TARGET}" = "gitsource" && test ${TRAVIS_BRANCH} = "master";
	then
		# Clone the latest tagged version of Plaso
		docker exec ${CONTAINER_NAME} sh -c "LATEST_TAG=`git ls-remote --tags https://github.com/log2timeline/plaso.git | sort -k2 | tail -n1 | sed 's?^.*refs/tags/??'` && git clone -b \${LATEST_TAG} https://github.com/log2timeline/plaso.git";

	else
		docker exec ${CONTAINER_NAME} sh -c "git clone https://github.com/log2timeline/plaso.git";
	fi
	if test "${TARGET}" = "pylint3";
	then
		docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "pylint --version";

		docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && find plaso/lib -name \\*.py -exec pylint --rcfile=.pylintrc {} \\;";
	else
		PYTHON="python3";

		if test "${TARGET}" = "gitsource";
		then
			# Install Plaso dependencies
			# TODO: remove the need for setting DEBIAN_FRONTEND
			docker exec -e "DEBIAN_FRONTEND=noninteractive" ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && ./config/linux/ubuntu_install_plaso.sh --include-test";

			# Run Plaso tests
			docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && python3 ./run_tests.py";
		else
			docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && python3 /usr/bin/log2timeline.py --status_view linear test.plaso test_data/image.qcow2";

			docker exec ${CONTAINER_OPTIONS} ${CONTAINER_NAME} sh -c "cd plaso && python3 /usr/bin/psort.py --status_view linear -w timeline.log test.plaso";
		fi
	fi

elif test "${TARGET}" = "dockerhub";
then
	CONTAINER_NAME="log2timeline/plaso";

	git clone https://github.com/log2timeline/plaso.git;

	docker run -v ${PWD}/plaso:/data ${CONTAINER_NAME} log2timeline --status_view linear /data/test.plaso /data/test_data/image.qcow2;

	docker run -v ${PWD}/plaso:/data ${CONTAINER_NAME} psort --status_view linear -w /data/timeline.log /data/test.plaso;

elif test ${TRAVIS_OS_NAME} = "osx";
then
	if test ${TRAVIS_BRANCH} = "master";
	then
		LATEST_TAG=`git ls-remote --tags https://github.com/log2timeline/plaso.git | sort -k2 | tail -n1 | sed 's?^.*refs/tags/??'` && git clone -b ${LATEST_TAG} https://github.com/log2timeline/plaso.git;
	else
		git clone https://github.com/log2timeline/plaso.git;
	fi

	cd plaso;

	# Set the following environment variables to build pycrypto and yara-python.
	export CFLAGS="-I/usr/local/include -I/usr/local/opt/openssl@1.1/include ${CFLAGS}";
	export LDFLAGS="-L/usr/local/lib -L/usr/local/opt/openssl@1.1/lib ${LDFLAGS}";
	export TOX_TESTENV_PASSENV="CFLAGS LDFLAGS";

	tox -e ${TOXENV};
fi
