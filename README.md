# Rudeck with CLI

Official Rundeck community image + RD CLI installed internally.
Additional shell script for auto-importing project and git-import SCM.

**WARNING**: script is unable to turn project SCM import on due to a bug, see [this issue](https://github.com/rundeck/rundeck-cli/issues/518)
That is why return-code of `rd projects scm status` return-code is now ignored.

## Image versioning:
Version tag is: `${RUNDECK_VERSION}-${SEQUENCE_ADDTIONAL_VERSION}`
where `SEQUENCE_ADDITIONAL_VERSION` is the digit of release appended by Octopusden maintainers while performing a release.

# Configuration
**WARNING**: global variable `${RUNDECK_HOME}` is set as `/home/rundeck` in the parent image by-default. It is **NOT** recommended to override it with another path. Internal `${RDECK_BASE}` variable is also set to `/home/rundeck` and we have these variables to be equal because of [this](https://docs.rundeck.com/docs/administration/security/authorization.html#policy-file-locations) and [this](https://github.com/rundeck/rundeck/issues/4052). We will **NOT** be able to apply static `.aclploicy` files otherwise.
Mount a volumes and store all dynamic Rundeck-related stuff inside a volume mounted to its subdirs.
All processes are started as `rundeck` user, so please make sure about the permissions for each volume.

## Main configuration templates
Should be available as `/etc/remco` structure inside a container.
There is a built-in `remco` template engine inside an original image (and since available here).

The default *remco* configuration (see below) translates all environment variables started with `RUNDECK_` prefix to *remco* global keys as `/rundeck/key/name` and may be rendered with `{{ getv("/rundeck/key/name" }}` instruction. If You override `/etc/remco/config.toml` by mounting a volume then this may be is not true. See *remco* documentation for configuration options.

Other environment variables may be translated inside each configuration template or rendered directly with *remco* `getenv` function. See [remco documentation](https://github.com/HeavyHorst/remco/blob/master/docs/content/template/template-functions.md) for details.

Configuration templates should be organized as the following structure inside a container:
- /etc/
    -- remco/
        --- config.toml - *remco* configuration. May be overwritten by mounting a volume.
        --- resources.d/ - a set of `*.toml` files with a rendering resource definitions. See official *Rundeck* image documentation for details.
        --- templates/ - a set of configuration templates. See *Rundeck* configuration documentation for details.

## SSH keys imported to the Rundeck keystore
Should available at `${RUNDECK_HOME}/etc/ssh-keys` folder inside a container.
Files with `*.priv.key` extenstion are imported as `keys/keyfileName.asc` to the keystore without any changes.

**WARNING**: due to limitations/bugs of *Java* libraries used inside *RunDeck* **ed25519**-keys are supported **only**.

## Passwords imported to the Rundeck keystore
All passwords are imported from environment variables passed to the container. Each variable named with suffix `_PASSWORD` is stored into the key `keys/${resource}_PASSWORD`, where `resource` is the name of the resource got from variable name. Example:
`SOMETHING_PASSWORD` ==> `keys/SOMETHING_PASSWORD`

## Importing projects
Rendered project templates should be available at `${RUNDECK_HOME}/etc/projects` inside a container.
The structure have to be:
- *projectName1*
    -- `project.properties` - a *Java*-compatible `.properties` file with project configuration.
    -- `scm-config.json` - *JSON*-configuration of `GitSCM` plugin to import job definitions from.
- *projectName2*
....

**NOTE** any project configuration may be designed as *remco* template also

## Importing nodes
Nodes definitions should be available as *JSON*-files anywhere inside a container. Recommended is `${RUNDECK_HOME}/etc/nodes`.
Nodes configuration files are referenced directly inside `project.properties` file by its absolut path, so their exact placement does not matter.

**NOTE**: node configuration may be designed as *remco* template also.

## Running Suggestions
- Mount volumes from server:
    -- `/home/rundeck/etc` - configuration files
    -- `/home/rundeck/server` - dynamic server data
    -- `/etc/remco` - with full configuration templates instead of defaults
- Store all rendered configuration files inside mounted volumes, along with SCM checks.

## TODO:
- migrate from *Rundeck CLI* to full-featured *Rundeck REST API*. This may fix the issue of auto-enabling *SCM* integration.
- add *SCM* Job import workaround.
- add *Valult* plugin and migrate all passwords to it.
