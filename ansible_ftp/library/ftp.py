from ftplib import FTP
from ansible.module_utils.basic import AnsibleModule


def main():
    module = AnsibleModule(
        argument_spec=dict(
            host=dict(type='str', required=True),
            port=dict(type='int', default=21),
            user=dict(type='str', required=True),
            password=dict(type='str', required=True),
            src=dict(type='str'),
            dest=dict(type='str'),
            command=dict(type='str', choices=["get", "put"], required=True)
        ),
        supports_check_mode=True
    )

    ftp = FTP()
    ftp.connect(module.params["host"], module.params["port"])
    ftp.login(module.params["user"], module.params["password"])

    if module.params["command"] == "put":
        with open(module.params["src"], 'rb') as file:
            out = ftp.storbinary("STOR " + module.params["dest"], file)
    elif module.params["command"] == "get":
        with open(module.params["dest"], 'wb') as file:
            out = ftp.retrbinary('RETR ' + module.params["src"], file.write)

    if "226" in out:
        result = dict(res=out, changed=True, failed=False)
    else:
        result = dict(res=out, changed=False, failed=True)

    module.exit_json(**result)


if __name__ == '__main__':
    main()
