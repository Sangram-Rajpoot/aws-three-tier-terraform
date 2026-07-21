const state = { projects: [], tasks: [], activity: [], dashboard: null };
const titles = { dashboard: 'Operations dashboard', projects: 'Project portfolio', tasks: 'Task delivery', activity: 'Activity stream' };

const byId = id => document.getElementById(id);
const escapeHtml = value => String(value ?? '').replace(/[&<>'"]/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', "'": '&#39;', '"': '&quot;' }[char]));
const pretty = value => String(value ?? '').replaceAll('_', ' ').replace(/\b\w/g, c => c.toUpperCase());
const dateText = value => value ? new Date(value).toLocaleString() : '-';

async function api(path, options = {}) {
  const response = await fetch(path, { headers: { 'Content-Type': 'application/json', ...(options.headers || {}) }, ...options });
  if (!response.ok) {
    let message = `Request failed (${response.status})`;
    try { const body = await response.json(); message = body.error || message; } catch (_) {}
    throw new Error(message);
  }
  if (response.status === 204) return null;
  return response.json();
}

function toast(message) {
  const element = byId('toast');
  element.textContent = message;
  element.classList.add('show');
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => element.classList.remove('show'), 2600);
}

function badge(value) { return `<span class="badge ${escapeHtml(value)}">${escapeHtml(pretty(value))}</span>`; }

async function checkHealth() {
  const indicator = byId('healthStatus');
  try {
    const result = await api('/api/health');
    indicator.textContent = result.status === 'healthy' ? 'API and database healthy' : 'API degraded';
    indicator.className = `health ${result.status === 'healthy' ? 'healthy' : 'unhealthy'}`;
  } catch (error) {
    indicator.textContent = 'API unavailable';
    indicator.className = 'health unhealthy';
  }
}

async function loadAll() {
  const [dashboard, projects, tasks, activity] = await Promise.all([
    api('/api/dashboard'), api('/api/projects'), api('/api/tasks'), api('/api/activity?limit=50')
  ]);
  Object.assign(state, { dashboard, projects, tasks, activity });
  renderAll();
  populateProjectOptions();
}

function renderMetrics() {
  const d = state.dashboard || { projects: { total: 0, by_status: {} }, tasks: { total: 0, by_status: {}, overdue: 0 } };
  byId('metrics').innerHTML = [
    ['Projects', d.projects.total, `${d.projects.by_status.active || 0} active`],
    ['Tasks', d.tasks.total, `${d.tasks.by_status.done || 0} completed`],
    ['In progress', d.tasks.by_status.in_progress || 0, `${d.tasks.by_status.review || 0} in review`],
    ['Overdue', d.tasks.overdue || 0, 'Open tasks past due date'],
  ].map(([label, value, note]) => `<article class="metric"><span>${label}</span><strong>${value}</strong><small>${note}</small></article>`).join('');
}

function renderDashboard() {
  renderMetrics();
  byId('dashboardProjects').innerHTML = state.projects.slice(0, 4).map(project => `
    <div class="project-row">
      <div class="project-row-header"><strong>${escapeHtml(project.name)}</strong>${badge(project.status)}</div>
      <p>${escapeHtml(project.description || 'No description')}</p>
      <small>${project.completed_task_count || 0}/${project.task_count || 0} tasks completed</small>
    </div>`).join('') || '<p class="empty">No projects found.</p>';
  byId('dashboardTasks').innerHTML = tasksTable(state.tasks.filter(t => t.status !== 'done').slice(0, 7), false);
  byId('dashboardActivity').innerHTML = activityHtml(state.activity.slice(0, 8));
}

function renderProjects() {
  const filter = byId('projectStatusFilter').value;
  const projects = filter ? state.projects.filter(p => p.status === filter) : state.projects;
  byId('projectsGrid').innerHTML = projects.map(project => `
    <article class="project-card">
      <div class="project-row-header"><h3>${escapeHtml(project.name)}</h3>${badge(project.status)}</div>
      <p>${escapeHtml(project.description || 'No description')}</p>
      <div class="project-meta"><span>Owner: ${escapeHtml(project.owner)}</span><span>${project.completed_task_count || 0}/${project.task_count || 0} done</span></div>
      <div class="project-card-actions"><button data-edit-project="${project.id}">Edit</button><button data-delete-project="${project.id}">Delete</button></div>
    </article>`).join('') || '<p class="empty">No projects match this filter.</p>';
}

function tasksTable(tasks, actions = true) {
  if (!tasks.length) return '<p class="empty">No tasks found.</p>';
  return `<table><thead><tr><th>Task</th><th>Project</th><th>Priority</th><th>Status</th><th>Assignee</th><th>Due</th>${actions ? '<th>Actions</th>' : ''}</tr></thead><tbody>${tasks.map(task => `
    <tr><td><strong>${escapeHtml(task.title)}</strong><br><small>${escapeHtml(task.description || '')}</small></td><td>${escapeHtml(task.project_name || '')}</td><td>${badge(task.priority)}</td><td>${badge(task.status)}</td><td>${escapeHtml(task.assignee || '-')}</td><td>${escapeHtml(task.due_date || '-')}</td>${actions ? `<td><div class="row-actions"><button data-edit-task="${task.id}">Edit</button><button data-delete-task="${task.id}">Delete</button></div></td>` : ''}</tr>`).join('')}</tbody></table>`;
}

function renderTasks() {
  const query = byId('taskSearch').value.trim().toLowerCase();
  const status = byId('taskStatusFilter').value;
  const tasks = state.tasks.filter(task => (!status || task.status === status) && (!query || [task.title, task.description, task.assignee, task.project_name].some(value => String(value || '').toLowerCase().includes(query))));
  byId('tasksTable').innerHTML = tasksTable(tasks, true);
}

function activityHtml(items) {
  return items.map(item => `<div class="activity-item"><span class="activity-dot"></span><div><p>${escapeHtml(item.message)}</p><small>${escapeHtml(pretty(item.event_type))} ${escapeHtml(item.entity_type)}</small></div><time>${dateText(item.created_at)}</time></div>`).join('') || '<p class="empty">No activity recorded.</p>';
}

function renderActivity() { byId('activityList').innerHTML = activityHtml(state.activity); }
function renderAll() { renderDashboard(); renderProjects(); renderTasks(); renderActivity(); }

function showView(view) {
  document.querySelectorAll('.view').forEach(element => element.classList.toggle('active', element.id === `${view}View`));
  document.querySelectorAll('.nav-item').forEach(element => element.classList.toggle('active', element.dataset.view === view));
  byId('pageTitle').textContent = titles[view];
  byId('newProjectButton').style.display = view === 'projects' || view === 'dashboard' ? '' : 'none';
}

function populateProjectOptions() {
  byId('taskProject').innerHTML = state.projects.map(project => `<option value="${project.id}">${escapeHtml(project.name)}</option>`).join('');
}

function openProject(project = null) {
  byId('projectDialogTitle').textContent = project ? 'Edit project' : 'Create project';
  byId('projectId').value = project?.id || '';
  byId('projectName').value = project?.name || '';
  byId('projectOwner').value = project?.owner || '';
  byId('projectStatus').value = project?.status || 'planned';
  byId('projectDescription').value = project?.description || '';
  byId('projectDialog').showModal();
}

function openTask(task = null) {
  if (!state.projects.length) return toast('Create a project first');
  byId('taskDialogTitle').textContent = task ? 'Edit task' : 'Create task';
  byId('taskId').value = task?.id || '';
  byId('taskProject').value = task?.project_id || state.projects[0].id;
  byId('taskTitle').value = task?.title || '';
  byId('taskPriority').value = task?.priority || 'medium';
  byId('taskStatus').value = task?.status || 'todo';
  byId('taskAssignee').value = task?.assignee || '';
  byId('taskDueDate').value = task?.due_date || '';
  byId('taskDescription').value = task?.description || '';
  byId('taskDialog').showModal();
}

async function refresh(message = '') {
  try { await loadAll(); await checkHealth(); if (message) toast(message); }
  catch (error) { toast(error.message); }
}

document.addEventListener('click', async event => {
  const target = event.target;
  if (target.matches('.nav-item')) showView(target.dataset.view);
  if (target.dataset.go) showView(target.dataset.go);
  if (target.dataset.close) byId(target.dataset.close).close();
  if (target.id === 'newProjectButton' || target.id === 'newProjectButtonInline') openProject();
  if (target.id === 'newTaskButton') openTask();
  if (target.id === 'refreshButton') refresh('Data refreshed');
  if (target.dataset.editProject) openProject(state.projects.find(p => p.id === Number(target.dataset.editProject)));
  if (target.dataset.editTask) openTask(state.tasks.find(t => t.id === Number(target.dataset.editTask)));
  if (target.dataset.deleteProject && confirm('Delete this project and all of its tasks?')) {
    try { await api(`/api/projects/${target.dataset.deleteProject}`, { method: 'DELETE' }); await refresh('Project deleted'); } catch (error) { toast(error.message); }
  }
  if (target.dataset.deleteTask && confirm('Delete this task?')) {
    try { await api(`/api/tasks/${target.dataset.deleteTask}`, { method: 'DELETE' }); await refresh('Task deleted'); } catch (error) { toast(error.message); }
  }
});

byId('projectForm').addEventListener('submit', async event => {
  event.preventDefault();
  const id = byId('projectId').value;
  const body = { name: byId('projectName').value, owner: byId('projectOwner').value, status: byId('projectStatus').value, description: byId('projectDescription').value };
  try {
    await api(id ? `/api/projects/${id}` : '/api/projects', { method: id ? 'PUT' : 'POST', body: JSON.stringify(body) });
    byId('projectDialog').close(); await refresh(id ? 'Project updated' : 'Project created');
  } catch (error) { toast(error.message); }
});

byId('taskForm').addEventListener('submit', async event => {
  event.preventDefault();
  const id = byId('taskId').value;
  const body = { project_id: Number(byId('taskProject').value), title: byId('taskTitle').value, priority: byId('taskPriority').value, status: byId('taskStatus').value, assignee: byId('taskAssignee').value, due_date: byId('taskDueDate').value || null, description: byId('taskDescription').value };
  try {
    await api(id ? `/api/tasks/${id}` : '/api/tasks', { method: id ? 'PUT' : 'POST', body: JSON.stringify(body) });
    byId('taskDialog').close(); await refresh(id ? 'Task updated' : 'Task created');
  } catch (error) { toast(error.message); }
});

byId('projectStatusFilter').addEventListener('change', renderProjects);
byId('taskStatusFilter').addEventListener('change', renderTasks);
byId('taskSearch').addEventListener('input', renderTasks);

refresh();
