# Ansible
Ansible es una herramienta que nos permite gestionar configuraciones, aprovisionamiento de recursos, despliegue automático de aplicaciones y muchas otras tareas de TI de una forma limpia y sencilla.

De forma predeterminada, Ansible administra máquinas mediante el protocolo SSH, sólo es necesario tener instalado Ansible en una máquina (la máquina de control), que es la que puede administrar el resto de máquinas clientes de forma remota y centralizada. En las máquinas remotas sólo hace falta que esté instalado Python.

## Requisitos
### Requisitos para la máquina de control
Actualmente Ansible puede ejecutarse desde cualquier máquina con Python 2 (versión 2.7) o Python 3 (versiones 3.5 y posteriores). La máquina de control no puede ser una máquina Windows.

### Requisitos de los nodos administrados
Necesitamos una forma de comunicarnos con los nodos gestionados, y se suele hacer mediante SSH. También se necesita Python 2 (versión 2.7) o Python 3 (versiones 3.5 y posteriores)

- [x] Python
- [x] OpenSSH Server

Instalando dependencias en Linux:
~~~
sudo apt-get install -y python-minimal openssh
~~~

Instalando dependencias en Windows (Powershell):
~~~
Invoke https://www.python.org/ftp/python/3.9.1/python-3.9.1-amd64.exe
~~~

~~~
Start-Service sshd
~~~

## Creación del contenedor 

Para ejecutar esta herramienta usare un contenedor Docker que he preparado con el siguiente Dockerfile basado en Alpine Linux:

~~~
FROM alpine:latest
LABEL maintainer="Luis A. <luis13cst@gmail.com>"

# Install Ansible and dependencies
RUN apk update && apk add ansible openssh nano

# Copy hosts and config file
COPY disk/etc/ansible /etc/ansible
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg
~~~

## Playbook en Windows
Luego para aplicar una configuración creamos un script el cual se conoce en Ansible como “playbook”, que contendrá diferentes tareas que a su vez estas contienen módulos de Ansible para facilitar la automatización de las configuraciones. Para los sistemas Windows se han utilizado modulos para borrar/crear usuarios y modificar el registro de Windows.

~~~
---
- name: Limpiando windows
  hosts: host.domain.ip
  become: true

  tasks:
  - name: borrar los usuarios
    win_user:
      name: user
      state: absent

  - name: crear usuarios
    win_user:
      name: asix
      password: B0bP4ssw0rd
      state: present
      groups:
        - Users

  - name: ensure local admin account exists
      win_user:
      name: localadmin
      password: '{{ local_admin_password }}'
      groups: Administrators

  - name: Remove Internet Explorer Logs
     win_eventlog:
      name: Internet Explorer
      state: absent

  - name: Ejecutar comando de Windows
     win_command: wmic cpu get caption, deviceid, name, numberofcores, maxclockspeed, status
     register: usage

  - name: Remove registry path (including all entries it contains)
    ansible.windows.win_regedit:
    path: HKCU:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\487214621
    state: absent
    delete_key: yes
~~~


## Ejecución en multiples hosts usando Inventory
Ansible trabaja contra múltiples sistemas en su infraestructura al mismo tiempo. Para ello, selecciona partes de los sistemas enumerados en el Inventory de Ansible, que por defecto se guarda en la ubicación /etc/ansible/hosts. 

Como podemos observar se declara el nombre del host y la IP para asociarlo a ese nombre, como configuración adicional he guardado los hosts en el grupo asix-dual-class.

~~~
[asix-dual-class]
aura12 ansible_host=11.22.33.44
aura13 ansible_host=22.33.44.55
~~~

Si un host no esta declarado en Inventory Ansible no podra acceder a él, también es posible y preferible en algunos casos declarar un Dynamic Inventory si tenemos una gran cantidad de hosts remotos y se actualizan con frecuencia. Por ejemplo en un escenario de un proveedor de cloud computing donde el inventario de los hosts ya existe, en ese caso, hacer uno propio sería simplemente una pérdida de tiempo. En la época del cloud computing, donde la infraestructura está creciendo bajo demanda, el archivo de inventario estático se volverá obsoleto rápidamente.


## Playbook de Linux
Para el playbook que se ejecutará en Linux usamos modulos diferentes, además de mostrar como se pasaría un comando de shell a variable de Ansible, para posteriormente usar esta variable como listado de usuarios a eliminar.

~~~
---
- name: Limpiando linux
  hosts: host.domain.ip
  become: true

  tasks:

  - name: Registing shell command (users for remove) like variable
    shell: 'awk -F: '($3 >= 1001) {printf "%s\n",$1}' /etc/passwd | sed '/nobody/d''
    register: remove_users_output

  - name: Remove Users
    user:
      name: "{{ item }}"
      state: absent
      with_items: "{{ remove_users_output }}"

  - name: Ensure user ricardo exists
    user:
    name: asix
    group: users
    groups: sudo
    uid: 1001
    password: "{{ 'lacontraseñasecreta' | password_hash('sha512') }}"
    state: present

  - name: Purge the user home
    command: "rm -rf /home/asix/"
    notify:
    - Run mkhomedir

  handlers:
    - name: Run mkhomedir
      command: "mkhomedir_helper asix"
~~~

## Conectando el cliente de Ansible

Si todo ha ido bien, hemos cumplido los requisitos y hemos copiado la clave publica SSH del servidor en el cliente (para acceder sin contraseña), deberíamos poder ejecutar un comando de prueba PING de Ansible. Podemos utilizar un comando ad-hoc de Ansible que simplemente se conectará al servidor remoto e informará el éxito o el fracaso.

~~~
ansible maquina_remota -m win_ping
~~~
