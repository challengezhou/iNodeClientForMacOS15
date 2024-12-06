
旧版本安装器的应用无法在最新版本的macOS如15上安装，可以使用Packages软件做二次封装  
本项目参照[https://github.com/helson-lin/iNode_Client_Sequoia](https://github.com/helson-lin/iNode_Client_Sequoia)，提取自己版本的iNodeClient的相应内容封装  
使用方法：  
clone本项目，Packages软件Build->Build/Build nd Run  
[Packages](http://s.sudre.free.fr/Software/Packages/about.html)官网  
项目操作步骤：  
1. 右键.pkg文件，显示包内容查看结构（需为安装器软件包，二次封装的安装器flat软件包无法再打开了）
2. 解压Archive.pax.gz文件
3. 打开Packages软件，新建Distribution项目，指定好目录，其他信息看着写写
4. 选择对应的Packages，主要需要设置的内容是Payload和Scripts
5. 需要将解压的Archive.pax.gz文件的内容复制到项目目录内，并设置到相应的Payload中
6. 对应Applications、Library目录在Payload界面可以看到，将相应的文件点加号放到对应的目录中，缺少上级目录的可以加目录后，右键目录Expand All,就能看到所有子目录了，右边Reference选择 Relative to Project，下同。否则自己用没问题，发给别人会找不到对应文件
7. 复制安装包内的preinstall和postintall脚本到项目目录
8. 有一些没有对应的目录，如iNode的/etc/local/lib 可在preinstall创建，通过命令复制进去，postinstall基本不需要修改，示例
```
# 1. 移动
mkdir /etc/iNode

# 2. 移动依赖文件
echo "/usr/local/lib目录检查"
# 检查目录是否存在
if [ -d "$LIB_TARGET_DIR" ]; then
  echo "Directory $LIB_TARGET_DIR already exists."
else
  echo "Directory $LIB_TARGET_DIR does not exist. Creating it..."
  # 创建目录并设置权限
  sudo mkdir -p "$LIB_TARGET_DIR"
  sudo chmod 755 "$LIB_TARGET_DIR"
  echo "Directory $LIB_TARGET_DIR created and permissions set to 755."
fi
```
9. 设置好后点上边`Build->Build/Build nd Run`运行
10. 安装器安装时可以点击`窗口->安装器日志`来查看日志
