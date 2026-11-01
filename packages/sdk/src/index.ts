export type CoreHealth = {status: string; version: string; uptimeSeconds: number};
export type Capability = {id: string; name: string; description: string; kind: string; version: string};
export type Project = {id:string; name:string};
export type Category = {id:string; name:string; open:boolean; projects:Project[]};
export type ProjectTree = {initialized:boolean; categories:Category[]};
export type PluginManifest = {id:string; name:string; version:string; kind:string; status:string; contributions?:Record<string,unknown>};
export class AINBWClient {
  constructor(private baseURL = '/api/v1'){}
  private async request<T>(endpoint:string, init?:RequestInit):Promise<T>{
    const response=await fetch(`${this.baseURL}${endpoint}`,init);
    if(!response.ok)throw new Error(`AINBW Core: ${response.status} ${response.statusText}`);
    return response.json() as Promise<T>;
  }
  health(){return this.request<CoreHealth>('/health');}
  capabilities(){return this.request<{capabilities:Capability[]}>('/capabilities');}
  plugins(){return this.request<{plugins:PluginManifest[]}>('/plugins');}
  projectTree(){return this.request<ProjectTree>('/project-tree');}
  saveProjectTree(categories:Category[]){return this.request<ProjectTree>('/project-tree',{method:'PUT',headers:{'Content-Type':'application/json'},body:JSON.stringify({categories})});}
}
