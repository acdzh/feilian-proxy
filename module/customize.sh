#!/system/bin/sh

# 设置权限
ui_print "- 设置权限"
set_perm_recursive $MODPATH/bin 0 0 0755 0755
set_perm_recursive $MODPATH/scripts 0 0 0755 0755
set_perm $MODPATH/service.sh 0 0 0755

ui_print "- 安装完成，重启生效"
