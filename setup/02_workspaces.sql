set echo on
whenever sqlerror exit

show user
show con_name

pause

/* uncomment to remove existing workspace, workspace admins, and database schemas
begin
  begin
    apex_instance_admin.remove_workspace(
        p_workspace  => 'PROD_WS',
        p_drop_users => 'Y'
    );
    exception when others then null;
  end;

  begin
    apex_instance_admin.remove_workspace(
        p_workspace  => 'DEMO_WS',
        p_drop_users => 'Y'
    );
    exception when others then null;
  end;
end;
/


-- create users and grant the necessary privileges
drop user if exists demo_ws_owner cascade;
drop user if exists prod_ws_owner cascade;

*/

create user demo_ws_owner identified by secret quota 1g on users;
create user prod_ws_owner identified by secret quota 1g on users;

begin
    for priv in (select PRIVILEGE from dba_sys_privs where grantee = 'APEX_GRANTS_FOR_NEW_USERS_ROLE')
    loop
        execute immediate 'grant ' || priv.privilege || ' to demo_ws_owner';
        execute immediate 'grant ' || priv.privilege || ' to prod_ws_owner';
        dbms_output.put_line('grant ' || priv.privilege || ' to demo_ws_owner');
        dbms_output.put_line('grant ' || priv.privilege || ' to prod_ws_owner');
    end loop;
end;
/

-- commission the PRODUCTION workspace
begin

  apex_instance_admin.add_workspace(
      p_workspace_id        => NULL,
      p_workspace           => 'PROD_WS',
      p_primary_schema      => 'PROD_WS_OWNER'
  );

  commit;

  apex_util.set_security_group_id(
      apex_util.find_security_group_id(
          p_workspace => 'PROD_WS'
      )
  );

  -- workspace admin
  apex_util.create_user(
      p_user_name => 'PROD_WS_ADMIN',
      p_email_address => 'martin.b.bach@oracle.com',
      p_default_schema => 'PROD_WS_OWNER',
      p_web_password => 'secret',
      p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
      p_change_password_on_first_use => 'N'
  );
 
  commit;
end;
/

-- commission the DEVELOPMENT workspace
begin

  apex_instance_admin.add_workspace(
      p_workspace_id        => NULL,
      p_workspace           => 'DEMO_WS',
      p_primary_schema      => 'DEMO_WS_OWNER'
  );

  commit;

  apex_util.set_security_group_id(
      apex_util.find_security_group_id(
          p_workspace => 'DEMO_WS'
      )
  );

  -- workspace admin
  apex_util.create_user(
      p_user_name => 'DEMO_WS_ADMIN',
      p_email_address => 'martin.b.bach@oracle.com',
      p_default_schema => 'DEMO_WS_OWNER',
      p_web_password => 'secret',
      p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL',
      p_change_password_on_first_use => 'N'
  );
 
  commit;
end;
/

whenever sqlerror continue

select
  username,
  oracle_maintained,
  account_status
from
  dba_users
where
  username in ('DEMO_WS_OWNER','PROD_WS_OWNER');

select
    workspace_display_name,
    workspace_name,
    schema
from
    apex_workspace_schemas;

select
    workspace_name,
    user_name,
    is_admin,
    is_application_developer
from
    apex_workspace_apex_users
where
    workspace_name in ('PROD_WS', 'DEMO_WS');

select
    count(*),
    owner
from
    dba_objects
where
    owner in ('PROD_WS', 'DEMO_WS')
group by
    owner;

set echo off