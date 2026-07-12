# Docker Compose Service — Ansible Role Skeleton

Copy this skeleton into `ansible/roles/<name>/tasks/main.yml` for any new homelab
Docker Compose service. Adjust paths, container names, and health checks per service.

```yaml
---
# Deploy <service-name> via Docker Compose (services/<name>/)
#
# Prerequisites: Docker, Tailscale, homelab docker network.

- name: Resolve <name> compose project path on target host
  ansible.builtin.set_fact:
    _<name>_compose_dir: "{{ homelab_repo_path }}/services/<name>"

- name: Ensure <name> compose directory on target host
  ansible.builtin.file:
    path: "{{ _<name>_compose_dir }}"
    state: directory
    owner: "{{ homelab_user }}"
    group: "{{ homelab_user }}"
    mode: "0755"

- name: Deploy <name> compose files to target host
  ansible.builtin.copy:
    src: "{{ playbook_dir }}/../../services/<name>/"
    dest: "{{ _<name>_compose_dir }}/"
    owner: "{{ homelab_user }}"
    group: "{{ homelab_user }}"

- name: Ensure <name> .env exists (from example, skip if present)
  ansible.builtin.copy:
    src: "{{ _<name>_compose_dir }}/.env.example"
    dest: "{{ _<name>_compose_dir }}/.env"
    remote_src: true
    owner: "{{ homelab_user }}"
    group: "{{ homelab_user }}"
    mode: "0600"
    force: false

- name: Ensure homelab docker network exists
  community.docker.docker_network:
    name: homelab
    state: present

- name: Deploy <name> compose stack
  community.docker.docker_compose_v2:
    project_src: "{{ _<name>_compose_dir }}"
    state: present
    env_files:
      - "{{ _<name>_compose_dir }}/.env"
  register: <name>_compose

- name: Verify <name> container is running
  community.docker.docker_container_info:
    name: <name>-proxy
  register: <name>_container
  failed_when: >-
    <name>_container.container.State.Status != 'running'
    or <name>_container.container.State.Health.Status != 'healthy'

- name: Show <name> deployment status
  ansible.builtin.debug:
    msg: >-
      <name> deployed to {{ _<name>_compose_dir }}
      (accessible at http://localhost:<port>/<endpoint>)
```

## Notes

- Replace `<name>` with the service name (e.g. `gmail-mcp`, `ollama`)
- Replace `<name>-proxy` with the actual container name from `compose.yaml`
- Replace `<port>/<endpoint>` with the service's access URL
- The `.env` file gets mode `0600` since it may contain secrets
- If the service doesn't have a `.env.example`, add one to `services/<name>/`
- The `docker_compose_v2` module requires `community.docker` collection (in `ansible/requirements.yml`)
