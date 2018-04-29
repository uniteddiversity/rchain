#!/usr/bin/env bash
## Tag and push newly built image if correct repo and branch.
set -eo pipefail

# Tag and push rnode docker container when it meets criteria.
if [[ "${TRAVIS_BRANCH}" = "master" || \
      "${TRAVIS_BRANCH}" = "dev" || \
      "${TRAVIS_BRANCH}" = "ops-test" ]] \
    && [[ "${TRAVIS_PULL_REQUEST}" = "false" && "${TRAVIS_REPO_SLUG}" = "rchain/rchain" ]] ; then

    echo "Travis branch ${TRAVIS_BRANCH} matched and from repo rchain/rchain. Pushing rnode to Docker repo."

    # Generate rnode debian and rpm packages - push to repo and then to p2p test net
    sbt -Dsbt.log.noformat=true clean rholang/bnfc:generate node/rpm:packageBin node/debian:packageBin 
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -P 10003 \
        node/target/rnode_0.2.1_all.deb \
        ${SSH_USERNAME}@repo.rchain.space:/usr/share/nginx/html/rnode_${TRAVIS_BRANCH}_all.deb
    scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -P 10003 node/target/rpm/RPMS/noarch/rnode-0.2.1-1.noarch.rpm \
        ${SSH_USERNAME}@repo.rchain.space:/usr/share/nginx/html/rnode-${TRAVIS_BRANCH}.noarch.rpm

    # Update rnode test network containers with branch
    for i in {1..4}; do

        # If first node set rnode cmd so it acts as bootstrap server
        if [[ $i == 1 ]]; then
            rnode_cmd="rnode --port 30304 --standalone --name 0f365f1016a54747b384b386b8e85352 > /var/log/rnode.log 2>&1 &"
        else
            rnode_cmd="rnode --bootstrap rnode://0f365f1016a54747b384b386b8e85352@10.1.1.2:30304 > /var/log/rnode.log 2>&1 &"
        fi
        
        ssh_tcp_port=$((40000+$i))
        ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
            -p ${ssh_tcp_port} ${SSH_USERNAME}@repo.rchain.space " 
                rm rnode_${TRAVIS_BRANCH}_all.deb;
                wget https://repo.rchain.space/rnode_${TRAVIS_BRANCH}_all.deb;
                pkill -9 rnode;
                pkill -9 java;
                apt -y remove --purge rnode;
                apt -y install ./rnode_${TRAVIS_BRANCH}_all.deb;
                ${rnode_cmd}
                " 
    done

else
    echo "Ignored. Build and tests not ran as not correct branch and from rchain/rchain repo."
fi
