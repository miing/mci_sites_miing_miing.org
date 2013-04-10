# Inherits
inherit_specs build/specs/common.sh

inherit_specs build/specs/dbengine.sh
inherit_specs build/specs/webserver.sh

inherit_specs build/specs/sso.sh
inherit_specs build/specs/cms.sh
inherit_specs build/specs/its.sh
inherit_specs build/specs/scmr.sh
inherit_specs build/specs/ci.sh

# Overrides
MCI_SITE_NAME=miing.org
MCI_SITE_CONFIG=sites/miing/miing.org/config
MCI_SITE_THEMES=sites/miing/miing.org/themes

MCI_DBENGINE_MYSQL_ROOTPW=xbml610XBML

MCI_SSO=migo
MCI_SSO_MIGO_SITE=login.miing.org

MCI_CMS=(cmscustom mediawiki)
MCI_CMS_CUSTOM_SITE=miing.org
MCI_CMS_MEDIAWIKI_SITE=wiki.miing.org
MCI_CMS_MEDIAWIKI_MYSQL_DBPW=mimw610MIMW
MCI_CMS_MEDIAWIKI_AUTH=openid

MCI_ITS=bugzilla
MCI_ITS_BUGZILLA_SITE=bugs.miing.org
MCI_ITS_BUGZILLA_MYSQL_DBPW=mibz610MIBZ
MCI_ITS_BUGZILLA_AUTH=openid

MCI_SCMR=gerrit
MCI_SCMR_GERRIT_SITE=review.miing.org
MCI_SCMR_GERRIT_MYSQL_DBPW=mige610MIGE
MCI_SCMR_GERRIT_AUTH=openidsso
MCI_SCMR_GERRIT_OPENIDSSO_URL=https://login.ubuntu.com/
MCI_SCMR_GERRIT_SSH_CONFIG=ssh.config
MCI_SCMR_GERRIT_SSHGIT_USER=miing
MCI_SCMR_GERRIT_SSHGIT_EMAIL=samuel.miing@gmail.com
MCI_SCMR_GERRIT_GIT_EDITOR=vim
MCI_SCMR_GERRIT_THEME=sapphire

MCI_CI=jenkins
MCI_CI_JENKINS_SITE=jenkins.miing.org
