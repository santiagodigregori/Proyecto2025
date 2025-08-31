#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Este script debe ejecutarse con privilegios de superusuario (root)."
    echo "Por favor, ejecute: sudo ./sicom_gestion.sh"
    exit 1
fi

TEST_BASE_DIR="$HOME/sicom_test"
LOG_FILE="$TEST_BASE_DIR/var/log/cuentas.log"

SKEL_BASE_DIR="$TEST_BASE_DIR/etc/skel_templates"
SKEL_ADMIN="$SKEL_BASE_DIR/admin"
SKEL_MOD_EDICION="$SKEL_BASE_DIR/moderadores_edicion"
SKEL_MOD_REVISION="$SKEL_BASE_DIR/moderadores_revision"
SKEL_MOD_SOPORTE="$SKEL_BASE_DIR/moderadores_soporte"
SKEL_CLIENTES_PROVEEDORES="$SKEL_BASE_DIR/clientes_proveedores"
SKEL_INVITADOS="$SKEL_BASE_DIR/invitados"

mkdir -p "$TEST_BASE_DIR/var/log"
mkdir -p "$SKEL_BASE_DIR"
mkdir -p "$SKEL_ADMIN"
mkdir -p "$SKEL_MOD_EDICION"
mkdir -p "$SKEL_MOD_REVISION"
mkdir -p "$SKEL_MOD_SOPORTE"
mkdir -p "$SKEL_CLIENTES_PROVEEDORES"
mkdir -p "$SKEL_INVITADOS"

EXECUTING_USER=$(logname 2>/dev/null || whoami)

log_action() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    local action="$1"
    local affected_entity="$2"
    echo "[$timestamp] [ACCION: $action] [ENTIDAD AFECTADA: $affected_entity] [EJECUTADO POR: $EXECUTING_USER]" | tee -a "$LOG_FILE" > /dev/null
}

aplicar_politica_chage() {
    local username="$1"
    echo "--- Configuración de políticas de contraseña para '$username' (chage) ---"
    read -p "¿Desea establecer una expiración de contraseña (ej. 90 días)? (s/n): " set_expire
    if [[ "$set_expire" == "s" || "$set_expire" == "S" ]]; then
        read -p "Días máximos antes de que la contraseña expire (M, ej. 90): " max_days
        if [[ "$max_days" =~ ^[0-9]+$ ]]; then
            chage -M "$max_days" "$username"
            echo "Contraseña de '$username' configurada para expirar en $max_days días."
            log_action "Configuración chage -M $max_days" "$username"
        else
            echo "Valor inválido para días máximos. No se aplicó."
            return 1
        fi

        read -p "Días de advertencia antes de la expiración (W, ej. 10): " warn_days
        if [[ "$warn_days" =~ ^[0-9]+$ ]]; then
            chage -W "$warn_days" "$username"
            echo "Advertencia de expiración para '$username' configurada $warn_days días antes."
            log_action "Configuración chage -W $warn_days" "$username"
        else
            echo "Valor inválido para días de advertencia. No se aplicó."
            return 1
        fi
    else
        echo "No se estableció una política de expiración de contraseña."
    fi
    return 0
}

crear_usuario() {
    local username_valido=false
    local user_type_description="$1"
    local group_name="$2"
    local user_shell="$3"
    local add_to_sudo="$4"
    local skel_path="$5"
    local username=""

    echo "--- Alta de usuario: $user_type_description ---"
    echo "NOTA: Las operaciones de creación/modificación/eliminación de usuarios/grupos"
    echo "afectarán al sistema real. El directorio de prueba ($TEST_BASE_DIR)"
    echo "se usa para logs y plantillas SKEL solamente."
    echo "----------------------------------------------------------------------"

    until "$username_valido"; do
        read -p "Ingrese el nombre de usuario (sin espacios): " username
        if [[ -z "$username" ]]; then
            echo "Error: El nombre de usuario no puede estar vacío."
        elif id "$username" &>/dev/null; then
            echo "Error: El usuario '$username' ya existe. Intente con otro nombre."
        elif [[ "$username" =~ [[:space:]] ]]; then
            echo "Error: El nombre de usuario no puede contener espacios."
        else
            username_valido=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    if [[ -n "$group_name" ]] && ! getent group "$group_name" &>/dev/null; then
        read -p "¿El grupo '$group_name' no existe. Desea crearlo? (s/n): " confirm_create_group
        if [[ "$confirm_create_group" == "s" || "$confirm_create_group" == "S" ]]; then
            groupadd "$group_name"
            if [ $? -ne 0 ]; then
                echo "Error: No se pudo crear el grupo '$group_name'. Abortando creación de usuario."
                log_action "Fallo en la creación de grupo ($group_name)" "N/A"
                read -p "Presione Enter para continuar..."
                return 1
            fi
            echo "Grupo '$group_name' creado."
        else
            echo "Creación de usuario cancelada. El grupo necesario no fue creado."
            read -p "Presione Enter para continuar..."
            return 1
        fi
    fi

    read -p "¿Confirma la creación del usuario '$username' de tipo '$user_type_description'? (s/n): " confirm_user_create
    if [[ "$confirm_user_create" != "s" && "$confirm_user_create" != "S" ]]; then
        echo "Creación de usuario cancelada."
        log_action "Alta de usuario cancelada por el usuario" "$username"
        read -p "Presione Enter para continuar..."
        return 1
    fi

    echo "Creando usuario '$username'..."
    local useradd_cmd="useradd -m -s \"$user_shell\""
    if [[ -n "$group_name" ]]; then
        useradd_cmd+=" -g \"$group_name\""
    fi

    if [[ -d "$skel_path" ]]; then
        useradd_cmd+=" -k \"$skel_path\""
        echo "Usando plantilla SKEL de prueba: $skel_path"
    else
        echo "Advertencia: La plantilla SKEL de prueba '$skel_path' no existe o no es un directorio. Se usará la plantilla por defecto del sistema (/etc/skel)."
    fi
    useradd_cmd+=" \"$username\""

    eval "$useradd_cmd"
    if [ $? -ne 0 ]; then
        echo "Error al crear usuario '$username'."
        log_action "Fallo en Alta de usuario ($user_type_description, SKEL: $skel_path)" "$username"
        read -p "Presione Enter para continuar..."
        return 1
    fi

    echo "Usuario '$username' creado exitosamente."
    if [[ "$add_to_sudo" == "true" ]]; then
        usermod -aG sudo "$username"
        if [ $? -ne 0 ]; then
            echo "Advertencia: No se pudo añadir a '$username' al grupo sudo."
            log_action "Fallo al añadir a sudo" "$username"
        else
            echo "Usuario '$username' añadido al grupo sudo."
        fi
    fi
    echo "Estableciendo contraseña para '$username'..."
    passwd "$username"
    if [ $? -ne 0 ]; then
        echo "Advertencia: No se pudo establecer la contraseña para '$username'."
        log_action "Fallo al establecer contraseña" "$username"
    fi

    aplicar_politica_chage "$username"
    log_action "Alta de usuario ($user_type_description, SKEL: $skel_path)" "$username"
    read -p "Presione Enter para continuar..."
    return 0
}

eliminar_usuario() {
    echo "--- Baja de usuario ---"
    echo "NOTA: Las operaciones de eliminación de usuarios afectarán al sistema real."
    echo "¡Esta acción es IRREVERSIBLE y eliminará el directorio home del usuario!"
    echo "----------------------------------------------------------------------"
    local username_exists=false
    local username=""

    until "$username_exists"; do
        read -p "Ingrese el nombre de usuario a eliminar: " username
        if [[ -z "$username" ]]; then
            echo "Error: El nombre de usuario no puede estar vacío."
        elif ! id "$username" &>/dev/null; then
            echo "Error: El usuario '$username' no existe."
        else
            username_exists=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    local active_processes=$(pgrep -u "$username")
    if [[ -n "$active_processes" ]]; then
        echo "Advertencia: El usuario '$username' tiene procesos activos:"
        ps -u "$username"
        read -p "¿Desea terminar estos procesos antes de eliminar al usuario? (s/n): " confirm_kill
        if [[ "$confirm_kill" == "s" || "$confirm_kill" == "S" ]]; then
            killall -u "$username"
            if [ $? -ne 0 ]; then
                echo "Error: No se pudieron terminar los procesos de '$username'."
                log_action "Fallo al terminar procesos" "$username"
                read -p "Presione Enter para continuar..."
                return 1
            fi
            echo "Procesos del usuario '$username' terminados."
            log_action "Terminación de procesos" "$username"
            sleep 1
        else
            echo "Operación de baja cancelada. No se eliminará el usuario '$username'."
            log_action "Baja de usuario cancelada (procesos activos)" "$username"
            read -p "Presione Enter para continuar..."
            return 1
        fi
    fi

    read -p "¿Está SEGURO de que desea ELIMINAR al usuario '$username' y su directorio home? (s/n): " confirm_delete
    if [[ "$confirm_delete" == "s" || "$confirm_delete" == "S" ]]; then
        userdel -r "$username"
        if [ $? -eq 0 ]; then
            echo "Usuario '$username' y su directorio home eliminados exitosamente."
            log_action "Baja de usuario" "$username"
            return 0
        else
            echo "Error al eliminar usuario '$username'."
            log_action "Fallo en Baja de usuario" "$username"
            return 1
        fi
    else
        echo "Operación de baja cancelada."
        log_action "Baja de usuario cancelada por el usuario" "$username"
        return 1
    fi
    read -p "Presione Enter para continuar..."
}

modificar_usuario() {
    echo "--- Modificación de usuario ---"
    echo "NOTA: Las operaciones de modificación de usuarios afectarán al sistema real."
    echo "----------------------------------------------------------------------"
    local username_exists=false
    local username=""

    until "$username_exists"; do
        read -p "Ingrese el nombre de usuario a modificar: " username
        if [[ -z "$username" ]]; then
            echo "Error: El nombre de usuario no puede estar vacío."
        elif ! id "$username" &>/dev/null; then
            echo "Error: El usuario '$username' no existe."
        else
            username_exists=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    local modify_option_valid=false
    until "$modify_option_valid"; do
        clear
        echo "--- ¿Qué desea modificar para '$username'? ---"
        echo "1. Cambiar contraseña"
        echo "2. Cambiar grupo(s)"
        echo "3. Cambiar nombre de usuario (¡Requiere precaución!)"
        echo "4. Aplicar/Modificar política de contraseña (chage)"
        echo "5. Volver al menú principal"
        read -p "Seleccione una opción: " modify_option

        case "$modify_option" in
            1)
                echo "Estableciendo nueva contraseña para '$username'..."
                passwd "$username"
                if [ $? -ne 0 ]; then
                    echo "Error al cambiar contraseña de '$username'."
                    log_action "Fallo en Modificación de contraseña" "$username"
                else
                    echo "Contraseña de '$username' cambiada exitosamente."
                    log_action "Modificación de contraseña" "$username"
                fi
                modify_option_valid=true
                ;;
            2)
                read -p "Ingrese el nuevo grupo primario (dejar vacío para no cambiar): " new_primary_group
                read -p "Ingrese los nuevos grupos suplementarios (separados por coma, dejar vacío para no cambiar): " new_supplementary_groups

                local usermod_cmd="usermod"
                local log_details=""
                local changes_made=false

                if [[ -n "$new_primary_group" ]]; then
                    if ! getent group "$new_primary_group" &>/dev/null; then
                        echo "Error: El grupo primario '$new_primary_group' no existe. Por favor, créelo primero."
                        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
                        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
                            echo "Volviendo al menú principal..."
                            read -p "Presione Enter para continuar..."
                            return 1
                        fi
                        sleep 2
                        continue
                    fi
                    usermod_cmd="$usermod_cmd -g $new_primary_group"
                    log_details+=" (Grupo Primario: $new_primary_group)"
                    changes_made=true
                fi

                if [[ -n "$new_supplementary_groups" ]]; then
                    local all_supplementary_exist=true
                    IFS=',' read -ra ADDR <<< "$new_supplementary_groups"
                    for g in "${ADDR[@]}"; do
                        if ! getent group "$g" &>/dev/null; then
                            echo "Error: El grupo suplementario '$g' no existe. Por favor, créelo primero."
                            all_supplementary_exist=false
                            break
                        fi
                    done
                    if ! "$all_supplementary_exist"; then
                        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
                        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
                            echo "Volviendo al menú principal..."
                            read -p "Presione Enter para continuar..."
                            return 1
                        fi
                        sleep 2
                        continue
                    fi
                    usermod_cmd="$usermod_cmd -aG $new_supplementary_groups"
                    log_details+=" (Grupos Suplementarios: $new_supplementary_groups)"
                    changes_made=true
                fi
                
                if "$changes_made"; then
                    read -p "¿Confirma los cambios de grupo para '$username'? (s/n): " confirm_group_change
                    if [[ "$confirm_group_change" == "s" || "$confirm_group_change" == "S" ]]; then
                        $usermod_cmd "$username"
                        if [ $? -ne 0 ]; then
                            echo "Error al modificar grupos de '$username'."
                            log_action "Fallo en Modificación de grupos$log_details" "$username"
                        else
                            echo "Grupos de '$username' modificados exitosamente."
                            log_action "Modificación de grupos$log_details" "$username"
                        fi
                    else
                        echo "Cambios de grupo cancelados."
                        log_action "Modificación de grupos cancelada" "$username"
                    fi
                else
                    echo "No se especificaron cambios de grupo."
                fi
                modify_option_valid=true
                ;;
            3)
                local new_username_valid=false
                local new_username=""
                until "$new_username_valid"; do
                    read -p "Ingrese el nuevo nombre de usuario para '$username': " new_username
                    if [[ -z "$new_username" ]]; then
                        echo "Error: El nuevo nombre de usuario no puede estar vacío."
                    elif id "$new_username" &>/dev/null; then
                        echo "Error: El usuario '$new_username' ya existe. Intente con otro nombre."
                    elif [[ "$new_username" =~ [[:space:]] ]]; then
                        echo "Error: El nuevo nombre de usuario no puede contener espacios."
                    else
                        new_username_valid=true
                        break
                    fi
                    
                    read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
                    if [[ "$choice" == "m" || "$choice" == "M" ]]; then
                        echo "Volviendo al menú principal..."
                        read -p "Presione Enter para continuar..."
                        return 1
                    fi
                    sleep 1
                done

                echo "¡ADVERTENCIA! Cambiar el nombre de usuario es una operación crítica que puede afectar el acceso a archivos y servicios."
                read -p "¿Está SEGURO de que desea cambiar el nombre de usuario de '$username' a '$new_username'? (s/n): " confirm_rename
                if [[ "$confirm_rename" == "s" || "$confirm_rename" == "S" ]]; then
                    usermod -l "$new_username" -d "/home/$new_username" -m "$username"
                    if [ $? -eq 0 ]; then
                        echo "Nombre de usuario de '$username' cambiado exitosamente a '$new_username'."
                        log_action "Modificación de nombre de usuario (de $username a $new_username)" "$new_username"
                    else
                        echo "Error al cambiar el nombre de usuario de '$username'."
                        log_action "Fallo en Modificación de nombre de usuario (de $username a $new_username)" "$username"
                    fi
                else
                    echo "Cambio de nombre de usuario cancelado."
                    log_action "Modificación de nombre de usuario cancelada" "$username"
                fi
                modify_option_valid=true
                ;;
            4)
                aplicar_politica_chage "$username"
                modify_option_valid=true
                ;;
            5)
                echo "Volviendo al menú principal."
                modify_option_valid=true
                ;;
            *)
                echo "Opción inválida. Por favor, ingrese un número del 1 al 5."
                sleep 1
                ;;
        esac
    done
    read -p "Presione Enter para continuar..."
    return 0
}

listar_usuarios() {
    echo "--- Listado de Usuarios ---"
    echo "Usuarios en el sistema:"
    echo "-------------------------"
    getent passwd | cut -d: -f1,3,4,7 | while IFS=: read -r user uid gid shell; do
        primary_group_name=$(getent group "$gid" | cut -d: -f1)
        echo "  Usuario: $user (UID: $uid, Grupo Primario: $primary_group_name, Shell: $shell)"
        supplementary_groups=$(id -Gn "$user" | sed "s/\b$primary_group_name\b//g" | sed "s/^ //;s/ $//;s/ /, /g")
        if [[ -n "$supplementary_groups" ]]; then
            echo "    Grupos Suplementarios: $supplementary_groups"
        fi
        echo ""
    done
    echo "-------------------------"
    log_action "Listado de usuarios" "N/A"
    read -p "Presione Enter para continuar..."
    return 0
}

listar_grupos() {
    echo "--- Listado de Grupos ---"
    echo "Grupos en el sistema:"
    echo "-------------------------"
    getent group | while IFS=: read -r group_name _ gid members; do
        echo "  - Nombre: $group_name (GID: $gid)"
        if [[ -n "$members" ]]; then
            echo "    Miembros: $(echo "$members" | sed 's/, /, /g')"
        else
            echo "    Miembros: Ninguno"
        fi
        echo ""
    done | sort -k3
    echo "-------------------------"
    log_action "Listado de grupos" "N/A"
    read -p "Presione Enter para continuar..."
    return 0
}

consultar_usuario_detalles() {
    echo "--- Consulta de detalles de usuario ---"
    local username_exists=false
    local username=""

    until "$username_exists"; do
        read -p "Ingrese el nombre de usuario a consultar: " username
        if [[ -z "$username" ]]; then
            echo "Error: El nombre de usuario no puede estar vacío."
        elif ! id "$username" &>/dev/null; then
            echo "Error: El usuario '$username' no existe."
        else
            username_exists=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    echo "--- Detalles para el usuario '$username' ---"
    echo "ID de Usuario y Grupos:"
    id "$username"
    echo ""

    echo "Información de /etc/passwd:"
    getent passwd "$username"
    echo ""

    echo "Información de Expiración de Contraseña (chage):"
    chage -l "$username"
    echo ""

    if command -v finger &>/dev/null; then
        echo "Información detallada (finger, si disponible):"
        finger "$username"
        echo ""
    fi

    log_action "Consulta de detalles de usuario" "$username"
    read -p "Presione Enter para continuar..."
    return 0
}

consultar_grupo_detalles() {
    echo "--- Consulta de detalles de grupo ---"
    local groupname_exists=false
    local groupname=""

    until "$groupname_exists"; do
        read -p "Ingrese el nombre del grupo a consultar: " groupname
        if [[ -z "$groupname" ]]; then
            echo "Error: El nombre del grupo no puede estar vacío."
        elif ! getent group "$groupname" &>/dev/null; then
            echo "Error: El grupo '$groupname' no existe."
        else
            groupname_exists=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    echo "--- Detalles para el grupo '$groupname' ---"
    getent group "$groupname" | while IFS=: read -r name _ gid members; do
        echo "Nombre del Grupo: $name"
        echo "GID (ID del Grupo): $gid"
        if [[ -n "$members" ]]; then
            echo "Miembros (usuarios en este grupo suplementario):"
            IFS=',' read -ra user_array <<< "$members"
            for user in "${user_array[@]}"; do
                echo "  - $user"
            done
        else
            echo "Miembros: Ninguno (o solo usuarios con este grupo como primario)"
        fi
    done
    echo ""
    log_action "Consulta de detalles de grupo" "$groupname"
    read -p "Presione Enter para continuar..."
    return 0
}

crear_grupo() {
    echo "--- Alta de Grupo ---"
    echo "NOTA: Las operaciones de creación de grupos afectarán al sistema real."
    echo "----------------------------------------------------------------------"
    local groupname_valido=false
    local groupname=""

    until "$groupname_valido"; do
        read -p "Ingrese el nombre del nuevo grupo (sin espacios): " groupname
        if [[ -z "$groupname" ]]; then
            echo "Error: El nombre del grupo no puede estar vacío."
        elif getent group "$groupname" &>/dev/null; then
            echo "Error: El grupo '$groupname' ya existe. Intente con otro nombre."
        elif [[ "$groupname" =~ [[:space:]] ]]; then
            echo "Error: El nombre del grupo no puede contener espacios."
        else
            groupname_valido=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    read -p "¿Confirma la creación del grupo '$groupname'? (s/n): " confirm_group_create
    if [[ "$confirm_group_create" != "s" && "$confirm_group_create" != "S" ]]; then
        echo "Creación de grupo cancelada."
        log_action "Alta de grupo cancelada por el usuario" "$groupname"
        read -p "Presione Enter para continuar..."
        return 1
    fi

    groupadd "$groupname"
    if [ $? -eq 0 ]; then
        echo "Grupo '$groupname' creado exitosamente."
        log_action "Alta de grupo" "$groupname"
        return 0
    else
        echo "Error al crear el grupo '$groupname'."
        log_action "Fallo en Alta de grupo" "$groupname"
        return 1
    fi
    read -p "Presione Enter para continuar..."
}

eliminar_grupo() {
    echo "--- Baja de Grupo ---"
    echo "NOTA: Las operaciones de eliminación de grupos afectarán al sistema real."
    echo "¡Esta acción es IRREVERSIBLE y puede afectar a los usuarios que lo tengan como grupo suplementario!"
    echo "----------------------------------------------------------------------"
    local groupname_exists=false
    local groupname=""

    until "$groupname_exists"; do
        read -p "Ingrese el nombre del grupo a eliminar: " groupname
        if [[ -z "$groupname" ]]; then
            echo "Error: El nombre del grupo no puede estar vacío."
        elif ! getent group "$groupname" &>/dev/null; then
            echo "Error: El grupo '$groupname' no existe."
        else
            groupname_exists=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    local members=$(getent group "$groupname" | cut -d: -f4)
    if [[ -n "$members" ]]; then
        echo "Advertencia: El grupo '$groupname' tiene los siguientes miembros: $members"
        read -p "¿Está SEGURO de que desea ELIMINAR este grupo? (Los usuarios mantendrán su grupo primario pero perderán este grupo suplementario) (s/n): " confirm_delete
    else
        read -p "¿Está SEGURO de que desea ELIMINAR el grupo '$groupname'? (s/n): " confirm_delete
    fi

    if [[ "$confirm_delete" == "s" || "$confirm_delete" == "S" ]]; then
        groupdel "$groupname"
        if [ $? -eq 0 ]; then
            echo "Grupo '$groupname' eliminado exitosamente."
            log_action "Baja de grupo" "$groupname"
            return 0
        else
            echo "Error al eliminar el grupo '$groupname'."
            log_action "Fallo en Baja de grupo" "$groupname"
            return 1
        fi
    else
        echo "Operación de baja de grupo cancelada."
        log_action "Baja de grupo cancelada por el usuario" "$groupname"
        return 1
    fi
    read -p "Presione Enter para continuar..."
}

modificar_grupo() {
    echo "--- Modificación de grupo ---"
    echo "NOTA: Las operaciones de modificación de grupos afectarán al sistema real."
    echo "----------------------------------------------------------------------"
    local groupname_exists=false
    local groupname=""

    until "$groupname_exists"; do
        read -p "Ingrese el nombre del grupo a modificar: " groupname
        if [[ -z "$groupname" ]]; then
            echo "Error: El nombre del grupo no puede estar vacío."
        elif ! getent group "$groupname" &>/dev/null; then
            echo "Error: El grupo '$groupname' no existe."
        else
            groupname_exists=true
            break
        fi
        
        read -p "¿Desea reintentar o volver al menú principal? (r/m): " choice
        if [[ "$choice" == "m" || "$choice" == "M" ]]; then
            echo "Volviendo al menú principal..."
            read -p "Presione Enter para continuar..."
            return 1
        fi
        sleep 1
    done

    local modify_option_valid=false
    until "$modify_option_valid"; do
        clear
        echo "--- ¿Qué desea modificar para el grupo '$groupname'? ---"
        echo "1. Añadir usuario(s) al grupo"
        echo "2. Quitar usuario(s) del grupo"
        echo "3. Volver al menú principal"
        read -p "Seleccione una opción: " modify_option

        case "$modify_option" in
            1)
                read -p "Ingrese el/los nombre(s) de usuario a añadir (separados por espacio): " users_to_add
                if [[ -z "$users_to_add" ]]; then
                    echo "No se especificaron usuarios para añadir."
                    modify_option_valid=true
                    continue
                fi
                read -p "¿Confirma añadir el/los usuario(s) '$users_to_add' al grupo '$groupname'? (s/n): " confirm_add_users
                if [[ "$confirm_add_users" != "s" && "$confirm_add_users" != "S" ]]; then
                    echo "Operación cancelada."
                    log_action "Modificación de grupo (añadir usuario) cancelada" "$groupname"
                    modify_option_valid=true
                    continue
                fi

                local success_count=0
                local fail_count=0
                for user in $users_to_add; do
                    if ! id "$user" &>/dev/null; then
                        echo "Error: El usuario '$user' no existe. Saltando."
                        ((fail_count++))
                        continue
                    fi
                    usermod -aG "$groupname" "$user"
                    if [ $? -eq 0 ]; then
                        echo "Usuario '$user' añadido a '$groupname' exitosamente."
                        log_action "Modificación de grupo (añadir usuario $user)" "$groupname"
                        ((success_count++))
                    else
                        echo "Error: No se pudo añadir a '$user' al grupo '$groupname'."
                        log_action "Fallo en Modificación de grupo (añadir usuario $user)" "$groupname"
                        ((fail_count++))
                    fi
                done
                echo "Operación de añadir usuarios completada. Éxito: $success_count, Fallo: $fail_count."
                modify_option_valid=true
                ;;
            2)
                read -p "Ingrese el/los nombre(s) de usuario a quitar (separados por espacio): " users_to_remove
                if [[ -z "$users_to_remove" ]]; then
                    echo "No se especificaron usuarios para quitar."
                    modify_option_valid=true
                    continue
                fi
                read -p "¿Confirma quitar el/los usuario(s) '$users_to_remove' del grupo '$groupname'? (s/n): " confirm_remove_users
                if [[ "$confirm_remove_users" != "s" && "$confirm_remove_users" != "S" ]]; then
                    echo "Operación cancelada."
                    log_action "Modificación de grupo (quitar usuario) cancelada" "$groupname"
                    modify_option_valid=true
                    continue
                fi

                local success_count=0
                local fail_count=0
                for user in $users_to_remove; do
                    if ! id "$user" &>/dev/null; then
                        echo "Error: El usuario '$user' no existe. Saltando."
                        ((fail_count++))
                        continue
                    fi
                    if ! id -nG "$user" | grep -qw "$groupname"; then
                        echo "Advertencia: El usuario '$user' no es miembro del grupo '$groupname'. Saltando."
                        ((fail_count++))
                        continue
                    fi
                    gpasswd -d "$user" "$groupname"
                    if [ $? -eq 0 ]; then
                        echo "Usuario '$user' quitado de '$groupname' exitosamente."
                        log_action "Modificación de grupo (quitar usuario $user)" "$groupname"
                        ((success_count++))
                    else
                        echo "Error: No se pudo quitar a '$user' del grupo '$groupname'."
                        log_action "Fallo en Modificación de grupo (quitar usuario $user)" "$groupname"
                        ((fail_count++))
                    fi
                done
                echo "Operación de quitar usuarios completada. Éxito: $success_count, Fallo: $fail_count."
                modify_option_valid=true
                ;;
            3)
                echo "Volviendo al menú principal."
                modify_option_valid=true
                ;;
            *)
                echo "Opción inválida. Por favor, ingrese un número del 1 al 3."
                sleep 1
                ;;
        esac
    done
    read -p "Presione Enter para continuar..."
    return 0
}

configurar_bloqueo_cuentas() {
    echo "--- Configuración de Bloqueo de Cuentas por Intentos Fallidos (PAM) ---"
    echo "¡ADVERTENCIA CRÍTICA!"
    echo "Esta función modificará la configuración de autenticación de su sistema (PAM)."
    echo "Un error en esta configuración puede dejar su sistema INACCESIBLE, incluso para el usuario root."
    echo "Asegúrese de entender los riesgos y de tener un plan de recuperación (ej. Live CD/USB)."
    echo "----------------------------------------------------------------------"
    read -p "¿Está ABSOLUTAMENTE SEGURO de que desea CONTINUAR y configurar el bloqueo de cuentas? (escriba 'si' para confirmar): " confirm_pam_config
    if [[ "$confirm_pam_config" != "si" ]]; then
        echo "Configuración de bloqueo de cuentas cancelada por el usuario."
        log_action "Configuración de bloqueo de cuentas cancelada" "N/A"
        read -p "Presione Enter para continuar..."
        return 1
    fi

    local pam_auth_file="/etc/pam.d/common-auth"
    local pam_account_file="/etc/pam.d/common-account"
    local backup_auth="$pam_auth_file.bak.$(date +%Y%m%d%H%M%S)"
    local backup_account="$pam_account_file.bak.$(date +%Y%m%d%H%M%S)"

    read -p "Ingrese el número máximo de intentos fallidos antes del bloqueo (ej. 3): " deny_attempts
    if ! [[ "$deny_attempts" =~ ^[0-9]+$ ]] || [ "$deny_attempts" -le 0 ]; then
        echo "Número de intentos inválido. Operación cancelada."
        log_action "Fallo en Configuración bloqueo cuentas (intentos invalidos)" "N/A"
        read -p "Presione Enter para continuar..."
        return 1
    fi

    read -p "Ingrese el tiempo de bloqueo de la cuenta en segundos (ej. 1800 para 30 minutos): " unlock_time_seconds
    if ! [[ "$unlock_time_seconds" =~ ^[0-9]+$ ]] || [ "$unlock_time_seconds" -le 0 ]; then
        echo "Tiempo de bloqueo inválido. Operación cancelada."
        log_action "Fallo en Configuración bloqueo cuentas (tiempo invalidos)" "N/A"
        read -p "Presione Enter para continuar..."
        return 1
    fi

    echo "Realizando copias de seguridad de los archivos PAM..."
    cp "$pam_auth_file" "$backup_auth"
    cp "$pam_account_file" "$backup_account"
    if [ $? -ne 0 ]; then
        echo "Error al crear copias de seguridad de PAM. Abortando."
        log_action "Fallo en Configuración bloqueo cuentas (backup PAM)" "N/A"
        read -p "Presione Enter para continuar..."
        return 1
    fi
    echo "Copias de seguridad creadas: $backup_auth y $backup_account"

    echo "Configurando $pam_auth_file..."
    if grep -q "pam_faillock.so" "$pam_auth_file"; then
        sed -i "/pam_faillock.so/c\auth required pam_faillock.so preauth audit deny=$deny_attempts unlock_time=$unlock_time_seconds" "$pam_auth_file"
        echo "Línea pam_faillock.so actualizada en common-auth."
    else
        if ! sed -i "/^auth/a auth required pam_faillock.so preauth audit deny=$deny_attempts unlock_time=$unlock_time_seconds" "$pam_auth_file"; then
            sed -i "1i\auth\s\+required\s\+pam_faillock.so\s\+preauth\s\+audit\s\+deny=$deny_attempts\s\+unlock_time=$unlock_time_seconds" "$pam_auth_file"
            echo "Línea pam_faillock.so añadida al inicio de common-auth."
        else
            echo "Línea pam_faillock.so añadida después de la primera 'auth' en common-auth."
        fi
    fi

    echo "Configurando $pam_account_file..."
    if grep -q "pam_faillock.so" "$pam_account_file"; then
        sed -i "/pam_faillock.so/c\account required pam_faillock.so" "$pam_account_file"
        echo "Línea pam_faillock.so actualizada en common-account."
    else
        if ! sed -i "/^account/a account required pam_faillock.so"; then
            sed -i "1i\account\s\+required\s\+pam_faillock.so" "$pam_account_file"
            echo "Línea pam_faillock.so añadida al inicio de common-account."
        else
            echo "Línea pam_faillock.so añadida después de la primera 'account' en common-account."
        fi
    fi

    echo "Configuración de bloqueo de cuentas aplicada exitosamente."
    echo "Las cuentas se bloquearán después de $deny_attempts intentos fallidos por $unlock_time_seconds segundos."
    log_action "Configuración bloqueo cuentas (deny=$deny_attempts, unlock_time=$unlock_time_seconds)" "N/A"
    read -p "Presione Enter para continuar..."
    return 0
}

mostrar_menu_principal() {
    local opcion_valida=false
    local opcion

    until "$opcion_valida"; do
        clear
        echo "--- Gestión de Usuarios y Grupos (ABMLC) ---"
        echo "USUARIOS:"
        echo "1. Alta (A): Crear nuevo usuario"
        echo "2. Baja (B): Eliminar usuario existente"
        echo "3. Modificación (M): Cambiar datos de usuario"
        echo "4. Listado (L): Mostrar lista de USUARIOS"
        echo "5. Consulta (C): Mostrar detalles de un USUARIO"
        echo "GRUPOS:"
        echo "6. Alta de Grupo: Crear nuevo grupo"
        echo "7. Baja de Grupo: Eliminar grupo existente"
        echo "8. Modificación (M): Cambiar datos de grupo"
        echo "9. Listado (L): Mostrar lista de GRUPOS"
        echo "10. Consulta (C): Mostrar detalles de un GRUPO"
        echo "SEGURIDAD ADICIONAL:"
        echo "11. Desactivar Login Directo de Root (Información Manual)"
        echo "12. Configurar Bloqueo de Cuentas por Intentos Fallidos (¡CRÍTICO!)"
        echo "13. Gestionar Permisos Sudoers (Información Manual)"
        echo "14. Salir"
        echo "-----------------------------------"
        read -p "Seleccione una opción: " opcion

        case "$opcion" in
            1|2|3|4|5|6|7|8|9|10|11|12|13|14) opcion_valida=true ;;
            *)
                echo "Opción inválida. Por favor, ingrese un número del 1 al 14."
                sleep 1
                ;;
        esac
    done
    REPLY=$opcion
    return 0
}

mostrar_submenu_alta() {
    local create_option_valid=false
    local create_option

    until "$create_option_valid"; do
        clear
        echo "--- Seleccione el tipo de usuario a crear (Alta) ---"
        echo "1. Nivel 1: admin"
        echo "2. Nivel 2: moderador (Edición)"
        echo "3. Nivel 2: moderador (Revisión)"
        echo "4. Nivel 2: moderador (Soporte)"
        echo "5. Nivel 3: cliente / proveedor"
        echo "6. Nivel 4: invitado"
        echo "7. Volver al menú principal"
        read -p "Seleccione una opción: " create_option

        case "$create_option" in
            1) crear_usuario "admin" "" "/bin/bash" "true" "$SKEL_ADMIN"; create_option_valid=true ;;
            2) crear_usuario "moderador de Edición" "moderadores_edicion" "/bin/bash" "false" "$SKEL_MOD_EDICION"; create_option_valid=true ;;
            3) crear_usuario "moderador de Revisión" "moderadores_revision" "/bin/bash" "false" "$SKEL_MOD_REVISION"; create_option_valid=true ;;
            4) crear_usuario "moderador de Soporte" "moderadores_soporte" "/bin/bash" "false" "$SKEL_MOD_SOPORTE"; create_option_valid=true ;;
            5)
                local cp_option_valid=false
                local cp_option
                until "$cp_option_valid"; do
                    clear
                    echo "--- Nivel 3: Cliente / Proveedor ---"
                    echo "1. Cliente"
                    echo "2. Proveedor"
                    echo "3. Volver al menú anterior"
                    read -p "Seleccione una opción: " cp_option

                    case "$cp_option" in
                        1) crear_usuario "cliente" "clientes_proveedores" "/bin/bash" "false" "$SKEL_CLIENTES_PROVEEDORES"; cp_option_valid=true; create_option_valid=true ;;
                        2) crear_usuario "proveedor" "clientes_proveedores" "/bin/bash" "false" "$SKEL_CLIENTES_PROVEEDORES"; cp_option_valid=true; create_option_valid=true ;;
                        3) echo "Volviendo al menú anterior."; cp_option_valid=true ;;
                        *) echo "Opción inválida. Por favor, ingrese un número del 1 al 3."; sleep 1 ;;
                    esac
                done
                ;;
            6) crear_usuario "invitado" "invitados" "/usr/sbin/nologin" "false" "$SKEL_INVITADOS"; create_option_valid=true ;;
            7) echo "Volviendo al menú principal."; create_option_valid=true ;;
            *) echo "Opción inválida. Por favor, ingrese un número del 1 al 7."; sleep 1 ;;
        esac
    done
    return 0
}

local seguir_ejecutando=false
until "$seguir_ejecutando"; do
    mostrar_menu_principal

    case "$REPLY" in
        1) mostrar_submenu_alta ;;
        2) eliminar_usuario ;;
        3) modificar_usuario ;;
        4) listar_usuarios ;;
        5) consultar_usuario_detalles ;;
        6) crear_grupo ;;
        7) eliminar_grupo ;;
        8) modificar_grupo ;;
        9) listar_grupos ;;
        10) consultar_grupo_detalles ;;
        11)
            echo "--- Desactivar Login Directo de Root (Información Manual) ---"
            echo "Para desactivar el login directo del usuario 'root' y mejorar la seguridad, siga estos pasos manuales:"
            echo "1.  Asegúrese de tener una cuenta de usuario regular con privilegios sudo (ej: su cuenta actual)."
            echo "2.  Para deshabilitar el login de root por consola/SSH (a menos que use 'su -'):"
            echo "    Ejecute: usermod -s /usr/sbin/nologin root"
            echo "    Esto cambiará el shell de root a uno que no permite login interactivo."
            echo "3.  Para deshabilitar el login de root por SSH (si usa SSH):"
            echo "    Edite el archivo /etc/ssh/sshd_config con un editor seguro (ej: nano /etc/ssh/sshd_config)."
            echo "    Busque la línea 'PermitRootLogin' y cámbiela a: PermitRootLogin no"
            echo "    Luego, reinicie el servicio SSH: systemctl restart sshd (o service ssh restart)"
            echo "Recuerde que cualquier cambio incorrecto en archivos de sistema puede bloquear su acceso."
            log_action "Info Desactivar Login Root" "N/A"
            read -p "Presione Enter para continuar..."
            ;;
        12)
            configurar_bloqueo_cuentas
            ;;
        13)
            echo "--- Gestión de Permisos Sudoers (Información Manual) ---"
            echo "La gestión de permisos en sudoers es fundamental para la seguridad y requiere precaución."
            echo "Para modificar el archivo /etc/sudoers de forma segura, DEBE usar el comando 'visudo'."
            echo "Ejecute en la terminal: visudo"
            echo "Este comando verifica la sintaxis de sudoers antes de guardar, evitando errores críticos."
            echo "Ejemplos de entradas en sudoers:"
            echo "  - Permitir a 'usuario' ejecutar todos los comandos con sudo sin contraseña:"
            echo "    usuario ALL=(ALL) NOPASSWD: ALL"
            echo "  - Permitir a 'mi_grupo' ejecutar ciertos comandos específicos con sudo:"
            echo "    %mi_grupo ALL=(ALL) /usr/bin/apt update, /usr/bin/apt upgrade"
            echo "Consulte 'man sudoers' para obtener la documentación completa."
            log_action "Info Gestionar Sudoers" "N/A"
            read -p "Presione Enter para continuar..."
            ;;
        14)
            echo "Saliendo del script. ¡Hasta luego!"
            seguir_ejecutando=true
            ;;
        *)
            echo "Opción inválida. Por favor, ingrese un número del 1 al 14."
            sleep 1
            ;;
    esac
done
