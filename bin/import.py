#!/usr/bin/env python3


if __name__ != "__main__":
    raise ImportError("Have to be run as script, import is not supported")

import argparse
import logging
from oc_cdtapi.RundeckAPI import RundeckAPI
import os
import posixpath

def main():
    """
    Main function
    """
    _p = argparse.ArgumentParser(description="Import Keys and Projects to Rundeck via RestAPI")
    _p.add_argument('--rundeck-url', dest="rundeck_url", help="Rundeck URL", default=os.getenv("RUNDECK_URL"))
    _p.add_argument('--rundeck-user', dest="rundeck_user", help="Rundeck user", default=os.getenv("RUNDECK_USER"))
    _p.add_argument('--rundeck-password', dest="rundeck_password", help="Rundeck password",
                    default=os.getenv("RUNDECK_PASSWORD"))
    _p.add_argument('--rundeck-home', dest="rundeck_home", help="Rundeck home directory",
                    default=os.getenv("RUNDECK_HOME") or "/home/rundeck")
    _p.add_argument('--log-level', dest="log_level", type=int, help="Logging level", default=20)
    
    _args = _p.parse_args()
    logging.basicConfig(format="%(pathname)s: %(asctime)-15s: %(levelname)s: %(funcName)s: %(lineno)d: %(message)s",
                        level=_args.log_level)
    logging.info(f"Logging level is set to [{_args.log_level}]")
    

    for _k, _v in _args.__dict__.items():

        if not isinstance(_v, bool) and not _v:
            raise ValueError(f"[{_k}] is mandatory but [{_v}] given.")

        _display_value = _v 
    
        if _v and _k.endswith('password'):
            _display_value = '*'*len(_v)
    
        logging.info(f"{_k.upper()}:\t[{_display_value}]")
        os.environ[_k.upper()] = _v if isinstance(_v, str) else str(_v)
    
    _args.rundeck_home = os.path.abspath(_args.rundeck_home)

    if not os.path.isdir(_args.rundeck_home):
        raise FileNotFoundError(_args.rundeck_home)

    _rundeck = RundeckAPI(url=_args.rundeck_url, user=_args.rundeck_user, password=_args.rundeck_password)
    _rundeck.web.verify = False

    import_secret_keys(_rundeck, _args.rundeck_home)
    import_passwords(_rundeck)
    import_projects(_rundeck, _args.rundeck_home)

def import_secret_keys(rundeck, rundeck_home):
    """
    Import secret keys from files to key storage
    :param RundeckAPI rundeck:
    :param str rundeck_home: rudeck home directory
    """
    _os_priv_key_extension = ".priv.key"
    _rundeck_priv_key_extension = ".sec"
    _keys_dir = os.path.join(rundeck_home, "etc", "ssh-keys")

    if not os.path.isdir(_keys_dir):
        logging.warning(f"Skipping import SSH private keys: not found: [{_keys_dir}])")
        return

    logging.info(f"Importing secret keys from [{_keys_dir}]")

    _files = list(filter(
        lambda _x: os.path.isfile(os.path.join(_keys_dir, _x)) and _x.endswith(_os_priv_key_extension),
        os.listdir(_keys_dir)))

    for _file in _files:
        _file_path = os.path.join(_keys_dir, _file)
        # replace extension due to Rundeck conventions
        # NOTE: "keys" part is appended by RundeckAPI as a constant, no need to do it here
        _rundeck_key_path = _file.replace(_os_priv_key_extension, _rundeck_priv_key_extension)
        logging.info(f"Importing [{_file_path}] as [_rundeck_key_path]")

        with open(_file_path, mode='rb') as _f:
            rundeck.key_storage__upload(_rundeck_key_path, "private", _f.read())

def import_passwords(rundeck):
    """
    Import passwords from environment variables
    :param RundeckAPI rundeck:
    """

    logging.info("Importing passwords from environment variables")

    for _k, _v in os.environ.items():
        if not _k.endswith("_PASSWORD"):
            logging.debug(f"Skipping [{_k}] - not a password")
            continue

        if not _v:
            logging.debug(f"Skipping [{_k}] - empty password")
            continue

        # NOTE: "keys" part is appended by RundeckAPI as a constant, no need to do it here
        _rundeck_key_path = _k
        logging.info(f"Importing [{_k}] as [{_rundeck_key_path}]")
        rundeck.key_storage__upload(_rundeck_key_path, "password", _v.encode("utf-8"))
    
def import_projects(rundeck, rundeck_home):
    """
    Import projects and their SCM configuration (if given)
    :param RundeckAPI rundeck:
    :param str rundeck_home: Rundeck home directory
    """
    _projects_dir = os.path.join(rundeck_home, "etc", "projects") 

    if not os.path.isdir(_projects_dir):
        logging.warning(f"Not importing projects: not found: [{_projects_dir}]")
        return

    logging.info(f"Importing projects from [{_projects_dir}]")

    _dirs = list(filter(
        lambda _x: os.path.isdir(os.path.join(_projects_dir, _x)), os.listdir(_projects_dir)))

    for _project in _dirs:
        _project_configuration = os.path.join(_projects_dir, _project, "project.properties")

        # FileNotFoundError will be raised on trying to open a file
        logging.info(f"Importing project [{_project}] configuration from [{_project_configuration}]")
        with open(_project_configuration, mode='rt') as _pc:
            rundeck.project__update(_pc)

        _scm_configuration = os.path.join(_projects_dir, _project, "scm-config.json")
        logging.info(f"Importing SCM configuration for project [{_project}] from [{_scm_configuration}]")

        with open(_scm_configuration, mode='rt') as _scmc:
            # NOTE: it is not nice to hardcode some values here
            #       but no other SCM and integration is planned for support in the future yet
            rundeck.scm__setup(_project, 'import', 'git-import', _scmc)
            rundeck.scm__enable(_project, 'import', 'git-import', True)
            rundeck.scm__perform_all_actions(_project, 'import', 'import-jobs')
    
main()
