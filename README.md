# Ansible
Para configurar la automatización del borrado de usuarios y limpiar el registro de Windows utilizaré la herramienta Ansible.

De forma predeterminada, Ansible administra máquinas mediante el protocolo SSH, sólo es necesario tener instalado Ansible en una máquina (la máquina de control), que es la que puede administrar el resto de máquinas clientes de forma remota y centralizada. En las máquinas remotas sólo hace falta que esté instalado Python.

## Requisitos
### Requisitos para la máquina de control
Actualmente Ansible puede ejecutarse desde cualquier máquina con Python 2 (versión 2.7) o Python 3 (versiones 3.5 y posteriores). La máquina de control no puede ser una máquina Windows.

### Requisitos de los nodos administrados
Necesitamos una forma de comunicarnos con los nodos gestionados, y se suele hacer mediante SSH. También se necesita Python 2 (versión 2.7) o Python 3 (versiones 3.5 y posteriores)

Descarga en Linux:
~~~
sudo apt-get install -y python-minimal
~~~

Descarga en Windows (Powershell):
~~~
Invoke https://www.python.org/ftp/python/3.9.1/python-3.9.1-amd64.exe
~~~

## Creación del contenedor 

Para ejecutar esta herramienta usare un contenedor Docker que he preparado con el siguiente Dockerfile:

~~~
FROM alpine:latest

RUN apk update && apk add ansible openssh nano
COPY disk/etc/ansible /etc/ansible
ENV ANSIBLE_CONFIG=/etc/ansible/ansible.cfg
~~~

## Playbook en Windows
Luego para aplicar una configuración creamos un script el cual se conoce en Ansible como “playbook”, que contendrá diferentes tareas que a su vez estas contienen módulos de Ansible para facilitar la creación de tasks.

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

  - name: Remove entry 'hello' from registry path MyCompany
    ansible.windows.win_regedit:
    path: HKCU:\Software\Microsoft\Windows NT\CurrentVersion\ProfileList\437165193
    name: hello

 



## Ejecución en multiples hosts usando Inventario (no dinamico)
Ansible trabaja contra múltiples sistemas en su infraestructura al mismo tiempo. Para ello, selecciona partes de los sistemas enumerados en el inventario de Ansible, que por defecto se guardan en la ubicación /etc/ansible/hosts.

~~~
[asix-dual-class]
aura12 ansible_host=11.22.33.44
aura13 ansible_host=22.33.44.55
# aura[11:13]
~~~

## Playbook de Linux


Con el siguiente comando vemos todos los usuarios que no sean root. awk -F: '($3 >= 1000) {printf "%s\n",$1}' /etc/passwd

~~~
  vars:
    myusers: ['root', 'bin', 'mail', 'obama', 'trump', 'clinton', 'you', 'me']

  tasks:
  - shell: 'cut -d: -f1 /etc/passwd'
    register: users
  - user: name={{item}} state=absent remove=yes
    with_items: users.stdout_lines
    when: item not in myusers
~~~

## Conectando el cliente Windows

Si todo ha ido bien, deberíamos poder ejecutar un comando de prueba PING de Ansible. Este comando simplemente se conectará al servidor WinServer1 remoto e informará el éxito o el fracaso.

~~~
ansible maquina_remota -m win_ping
~~~
