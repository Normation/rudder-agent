# signs reports

if [ -f "${RUDDER_JSON}" ]; then
  DAVUSER=$(rudder_json_value 'DAVUSER')
  DAVPW=$(rudder_json_value 'DAVPASSWORD')
fi

SERVER=$(cat "${RUDDER_VAR}/cfengine-community/policy_server.dat")
TMP_REPORTS_DIR="/var/rudder/tmp/reports/"
REPORTS_DIR="/var/rudder/reports/ready/"

mkdir -p "${TMP_REPORTS_DIR}"
mkdir -p "${REPORTS_DIR}"

# The key to use for signature
PRIVKEY="/var/rudder/cfengine-community/ppkeys/localhost.priv"
CERT="/opt/rudder/etc/ssl/agent.cert"

# Private key passphrase
PASSPHRASE="Cfengine passphrase"

# Should be called on the output file from temp directory
# Everything in the ready dir should be ready to be sent
compress_and_sign() {
    # filename
    file="$1"
    tmp_file="${TMP_REPORTS_DIR}/${file}"
    ready_file="${REPORTS_DIR}/${file}.gz"

    # Do not send an empty file
    if ! [ -f "${tmp_file}" ] || [ -z "$(cat ${tmp_file})" ]; then
        echo "${blue}info${normal}: empty runlog, skipping reporting"
        rm -f "${tmp_file}"
        return
    fi

    # We do not include certs as the server already knows them
    openssl smime -sign -text -nocerts -signer "${CERT}" -inkey "${PRIVKEY}" -passin "pass:${PASSPHRASE}" \
        -in "${tmp_file}" -out "${tmp_file}.signed"
    if [ $? -eq 0 ]; then
        # Move temp file
        mv "${tmp_file}.signed" "${tmp_file}"
    else
        echo "${red}error${normal}: ${tmp_file} could not be signed"
        rm -f "${tmp_file}.signed"
        exit 1
    fi

    gzip -f "${tmp_file}"
    if [ $? -ne 0 ]; then
        echo "${red}error${normal}: Could not compress ${tmp_file}, exiting"
        return 1
    fi

    # (Very likely) atomic move in ready reports dir
    mv "${tmp_file}.gz" "${ready_file}"

    # Try to send it.
    # If it fails, it will be sent later by the agent
    curl --tlsv1.2 ${CERTIFICATE_OPTION} --fail --silent --proxy '' --user "${DAVUSER}:${DAVPW}" --upload-file "${ready_file}" https://${SERVER}/reports/ >/dev/null
    # keep the code sinc curl has a very comprehensive error code list
    code=$?
    if [ ${code} -eq 0 ]; then
        # Remove temp file
        rm "${ready_file}"
        echo "Reports sent."
    else
        # Keep the runlog for future upload by the agent
        echo "${yellow}warning${normal}: Could not send ${ready_file} (error ${code}), it will be retried later"
    fi  
}
