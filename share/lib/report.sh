# signs reports

if [ -f "${RUDDER_JSON}" ]; then
  DAVUSER=$(rudder_json_value 'DAVUSER')
  DAVPW=$(rudder_json_value 'DAVPASSWORD')
  INITIAL=$(rudder_json_bool_value 'INITIAL')
fi

SERVER=$(cut -d: -f1 "${RUDDER_VAR}/cfengine-community/policy_server.dat")
TMP_REPORTS_DIR="${RUDDER_VAR}/tmp/reports/"
REPORTS_DIR="${RUDDER_VAR}/reports/ready/"

mkdir -p "${TMP_REPORTS_DIR}"
mkdir -p "${REPORTS_DIR}"

# The key to use for signature
PRIVKEY="${RUDDER_VAR}/cfengine-community/ppkeys/localhost.priv"
CERT="${RUDDER_DIR}/etc/ssl/agent.cert"

# Should be called on the output file from temp directory
# Everything in the ready dir should be ready to be sent
compress_and_sign() {
    # filename
    file="$1"
    tmp_file="${TMP_REPORTS_DIR}/${file}"
    ready_file="${REPORTS_DIR}/${file}.gz"

    # Do not send report from initial policies
    if [ "${INITIAL}" = "true" ]; then
        echo "${blue}info${normal}: initial policies, skipping reporting"
        rm -f "${tmp_file}"
        return
    fi

    # Do not send an empty file
    if ! [ -f "${tmp_file}" ] || [ -z "$(cat ${tmp_file})" ]; then
        echo "${blue}info${normal}: empty runlog, skipping reporting"
        rm -f "${tmp_file}"
        return
    fi

    # Only include the certs in certificate verification mode
    if is_cert_validated; then
      include_certs=""
    else
      include_certs="-nocerts"
    fi

    openssl smime -sign -text ${include_certs} -signer "${CERT}" -inkey "${PRIVKEY}" \
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
    /opt/rudder/bin/rudder-client -e /reports/ -- --upload-file "${ready_file}" >/dev/null
    # keep the code since curl has a very comprehensive error code list
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
