import { revision } from './store.js';

const taskFields = ['id', 'title', 'projectId', 'parentId', 'subTaskIds', 'notes', 'isDone', 'tagIds', 'dueDay', 'dueWithTime', 'plannedAt', 'timeEstimate', 'timeSpent'];
const editable = ['title', 'notes', 'isDone', 'projectId', 'tagIds', 'dueDay', 'dueWithTime', 'plannedAt', 'timeEstimate'];
export const taskView = task => Object.fromEntries(taskFields.filter(k => task[k] !== undefined).map(k => [k, task[k]]));
export const taskRevision = task => revision(taskView(task));

export class Bridge {
  constructor(api, store, allowedProjects = []) { this.api = api; this.store = store; this.allowed = new Set(allowedProjects); }
  permits(id) { return !this.allowed.size || this.allowed.has(id); }
  assertProject(id) { if (!this.permits(id)) throw new Error('PROJECT_NOT_ALLOWED'); }
  async projects() {
    return (await this.api.projects()).filter(p => this.permits(p.id)).map(p => ({ id: p.id, title: p.title, isArchived: !!p.isArchived }));
  }
  async activeProject(id) {
    this.assertProject(id);
    if (!(await this.projects()).some(p => p.id === id && !p.isArchived)) throw new Error('PROJECT_NOT_FOUND: use an exact active project ID from list_projects.');
  }
  async search(filters) {
    if (filters.projectId) this.assertProject(filters.projectId);
    return (await this.api.tasks(filters)).filter(t => this.permits(t.projectId)).map(taskView);
  }
  async getTask(id) {
    const task = await this.api.task(id); this.assertProject(task.projectId);
    return { task: taskView(task), revision: taskRevision(task) };
  }
  async projectBrief(projectId) {
    await this.activeProject(projectId);
    const project = (await this.projects()).find(p => p.id === projectId);
    const tasks = await this.search({ projectId, includeDone: true, source: 'active' });
    const context = this.store.brief(projectId);
    return { project, context, fetchedAt: new Date().toISOString(), total: tasks.length, done: tasks.filter(t => t.isDone).length, tasks };
  }
  async saveBrief({ projectId, text, expectedRevision }) {
    await this.activeProject(projectId);
    return this.store.saveBrief(projectId, text, expectedRevision);
  }
  async create(args) {
    const { requestId, ...fields } = args;
    return this.store.mutate(requestId, { action: 'create_task', ...fields }, async () => {
      await this.activeProject(fields.projectId);
      const task = await this.api.create(fields);
      return { task: taskView(task), revision: taskRevision(task) };
    });
  }
  async update(args) {
    const { requestId, taskId, expectedRevision, changes } = args;
    return this.store.mutate(requestId, { action: 'update_task', taskId, expectedRevision, changes }, async recordBefore => {
      if (!Object.keys(changes).length || Object.keys(changes).some(k => !editable.includes(k))) throw new Error('UNSUPPORTED_FIELDS');
      const before = await this.api.task(taskId); this.assertProject(before.projectId);
      if (taskRevision(before) !== expectedRevision) throw new Error('CONFLICT: task changed since it was read. Call get_task again and reconcile the changes.');
      if (changes.projectId) await this.activeProject(changes.projectId);
      recordBefore(taskView(before));
      const task = await this.api.update(taskId, changes);
      return { task: taskView(task), revision: taskRevision(task) };
    });
  }
}
