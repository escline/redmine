Redmine::Application.routes.draw do |map|
  # Add your own custom routes here.
  # The priority is based upon order of creation: first created -> highest priority.

  # Here's a sample route:
  # map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  map.home '', :controller => 'welcome'

  map.signin 'login', :controller => 'account', :action => 'login'
  map.signout 'logout', :controller => 'account', :action => 'logout'

  map.connect 'roles/workflow/:id/:role_id/:tracker_id', :controller => 'roles', :action => 'workflow'
  map.connect 'help/:ctrl/:page', :controller => 'help'

  map.with_options :controller => 'time_entry_reports', :action => 'report',:conditions => {:method => :get} do |time_report|
    time_report.connect 'projects/:project_id/issues/:issue_id/time_entries/report'
    time_report.connect 'projects/:project_id/issues/:issue_id/time_entries/report.:format'
    time_report.connect 'projects/:project_id/time_entries/report'
    time_report.connect 'projects/:project_id/time_entries/report.:format'
    time_report.connect 'time_entries/report'
    time_report.connect 'time_entries/report.:format'
  end

  map.bulk_edit_time_entry 'time_entries/bulk_edit',
                   :controller => 'timelog', :action => 'bulk_edit', :conditions => { :method => :get }
  map.bulk_update_time_entry 'time_entries/bulk_edit',
                   :controller => 'timelog', :action => 'bulk_update', :conditions => { :method => :post }
  map.time_entries_context_menu '/time_entries/context_menu',
                   :controller => 'context_menus', :action => 'time_entries'
                   
  map.resources :time_entries, :controller => 'timelog', :collection => {:report => :get, :bulk_edit => :get, :bulk_update => :post}

  map.connect 'projects/:id/wiki', :controller => 'wikis', :action => 'edit', :conditions => {:method => :post}
  map.connect 'projects/:id/wiki/destroy', :controller => 'wikis', :action => 'destroy', :conditions => {:method => :get}
  map.connect 'projects/:id/wiki/destroy', :controller => 'wikis', :action => 'destroy', :conditions => {:method => :post}

  map.with_options :controller => 'messages' do |messages_routes|
    messages_routes.with_options :conditions => {:method => :get} do |messages_views|
      messages_views.connect 'boards/:board_id/topics/new', :action => 'new'
      messages_views.connect 'boards/:board_id/topics/:id', :action => 'show'
      messages_views.connect 'boards/:board_id/topics/:id/edit', :action => 'edit'
      messages_views.connect 'boards/:board_id/topics/:id/quote', :action => 'quote'
    end
    messages_routes.with_options :conditions => {:method => :post} do |messages_actions|
      messages_actions.connect 'boards/:board_id/topics/new', :action => 'new'
      messages_actions.connect 'boards/:board_id/topics/:id/replies', :action => 'reply'
      messages_actions.connect 'boards/:board_id/topics/:id/:action', :action => /edit|destroy/
    end
  end

  map.with_options :controller => 'boards' do |board_routes|
    board_routes.with_options :conditions => {:method => :get} do |board_views|
      board_views.connect 'projects/:project_id/boards', :action => 'index'
      board_views.connect 'projects/:project_id/boards/new', :action => 'new'
      board_views.connect 'projects/:project_id/boards/:id', :action => 'show'
      board_views.connect 'projects/:project_id/boards/:id.:format', :action => 'show'
      board_views.connect 'projects/:project_id/boards/:id/edit', :action => 'edit'
    end
    board_routes.with_options :conditions => {:method => :post} do |board_actions|
      board_actions.connect 'projects/:project_id/boards', :action => 'new'
      board_actions.connect 'projects/:project_id/boards/:id/:action', :action => /edit|destroy/
    end
  end

  map.with_options :controller => 'documents' do |document_routes|
    document_routes.with_options :conditions => {:method => :get} do |document_views|
      document_views.connect 'projects/:project_id/documents', :action => 'index'
      document_views.connect 'projects/:project_id/documents/new', :action => 'new'
      document_views.connect 'documents/:id', :action => 'show'
      document_views.connect 'documents/:id/edit', :action => 'edit'
    end
    document_routes.with_options :conditions => {:method => :post} do |document_actions|
      document_actions.connect 'projects/:project_id/documents', :action => 'new'
      document_actions.connect 'documents/:id/:action', :action => /destroy|edit/
    end
  end
  
  map.resources :issue_moves, :only => [:new, :create], :path_prefix => '/issues', :as => 'move'
  map.resources :queries, :except => [:show]

  # Misc issue routes. TODO: move into resources
  map.auto_complete_issues '/issues/auto_complete', :controller => 'auto_completes', :action => 'issues'
  map.preview_issue '/issues/preview/:id', :controller => 'previews', :action => 'issue' # TODO: would look nicer as /issues/:id/preview
  map.issues_context_menu '/issues/context_menu', :controller => 'context_menus', :action => 'issues'
  map.issue_changes '/issues/changes', :controller => 'journals', :action => 'index'
  map.bulk_edit_issue 'issues/bulk_edit', :controller => 'issues', :action => 'bulk_edit', :conditions => { :method => :get }
  map.bulk_update_issue 'issues/bulk_edit', :controller => 'issues', :action => 'bulk_update', :conditions => { :method => :post }
  map.quoted_issue '/issues/:id/quoted', :controller => 'journals', :action => 'new', :id => /\d+/, :conditions => { :method => :post }
  map.connect '/issues/:id/destroy', :controller => 'issues', :action => 'destroy', :conditions => { :method => :post } # legacy

  map.with_options :controller => 'gantts', :action => 'show' do |gantts_routes|
    gantts_routes.connect '/projects/:project_id/issues/gantt'
    gantts_routes.connect '/projects/:project_id/issues/gantt.:format'
    gantts_routes.connect '/issues/gantt.:format'
  end

  map.with_options :controller => 'calendars', :action => 'show' do |calendars_routes|
    calendars_routes.connect '/projects/:project_id/issues/calendar'
    calendars_routes.connect '/issues/calendar'
  end

  map.with_options :controller => 'reports', :conditions => {:method => :get} do |reports|
    reports.connect 'projects/:id/issues/report', :action => 'issue_report'
    reports.connect 'projects/:id/issues/report/:detail', :action => 'issue_report_details'
  end

  map.connect 'projects/:id/members/new', :controller => 'members', :action => 'new'

  map.with_options :controller => 'users' do |users|
    users.connect 'users/:id/edit/:tab', :action => 'edit', :tab => nil, :conditions => {:method => :get}

    users.with_options :conditions => {:method => :post} do |user_actions|
      user_actions.connect 'users/:id/memberships', :action => 'edit_membership'
      user_actions.connect 'users/:id/memberships/:membership_id', :action => 'edit_membership'
      user_actions.connect 'users/:id/memberships/:membership_id/destroy', :action => 'destroy_membership'
    end
  end

  map.resources :users, :member => {
    :edit_membership => :post,
    :destroy_membership => :post
  }

  # For nice "roadmap" in the url for the index action
  map.connect '/projects/:project_id/roadmap', :controller => 'versions', :action => 'index'
  
  map.preview_news '/news/preview', :controller => 'previews', :action => 'news'

  map.wiki_start_page '/projects/:project_id/wiki/index', :controller => 'wiki', :action => 'index', :conditions => {:method => :get}
  map.wiki_start_page '/projects/:project_id/wiki/date_index', :controller => 'wiki', :action => 'date_index', :conditions => {:method => :get}
  map.wiki_start_page '/projects/:project_id/wiki/export', :controller => 'wiki', :action => 'export', :conditions => {:method => :get}
  map.wiki_start_page '/projects/:project_id/wiki/:id', :controller => 'wiki', :action => 'show', :conditions => {:method => :get}

  map.resources :projects, :shallow => true, :member => {
    :copy => [:get, :post],
    :settings => :get,
    :modules => :put,
    :archive => :post,
    :unarchive => :post
  } do |project|
    project.resource :project_enumerations, :as => 'enumerations', :only => [:update, :destroy]
    project.resources :files, :only => [:index, :new, :create]
    project.resources :versions, :collection => {:close_completed => :put}, :member => {:status_by => :post}
    project.resources :news, :shallow => true do |news|
      news.resources :comments
    end
    project.resources :time_entries, :controller => 'timelog'

    project.resources :issues, :shallow => true do |issues|
      issues.resources :time_entries, :controller => 'timelog'
      issues.resources :relations, :controller => 'issue_relations', :only => [:index, :show, :create, :destroy]
      issues.resources :time_entries, :controller => 'timelog'
    end

    project.resources :queries, :only => [:new, :create]
    project.resources :issue_categories, :shallow => true

    project.connect 'settings/:tab', :controller => 'projects', :action => 'settings', :conditions => {:method => :get}, :path_prefix => 'projects/:id'

    project.resources :wiki, :shallow => true, :except => [:new, :create], :member => {
      :rename => [:get, :put],
      :history => :get,
      :preview => :any,
      :protect => :post,
      :add_attachment => :post
    }
    project.wiki_diff 'wiki/:id/diff/:version', :controller => 'wiki', :action => 'diff', :version => nil
    project.wiki_diff 'wiki/:id/diff/:version/vs/:version_from', :controller => 'wiki', :action => 'diff'
    project.wiki_annotate 'wiki/:id/annotate/:version', :controller => 'wiki', :action => 'annotate'
    
    project.resources :queries
    project.resources :documents
    project.resources :boards
  end

  # Destroy uses a get request to prompt the user before the actual DELETE request
  map.project_destroy_confirm 'projects/:id/destroy', :controller => 'projects', :action => 'destroy', :conditions => {:method => :get}

  # TODO: port to be part of the resources route(s)
  map.with_options :controller => 'projects' do |project_mapper|
    project_mapper.with_options :conditions => {:method => :get} do |project_views|
      project_views.connect 'projects/:project_id/issues/:copy_from/copy', :controller => 'issues', :action => 'new'
    end
  end

  map.with_options :controller => 'activities', :action => 'index', :conditions => {:method => :get} do |activity|
    activity.connect 'projects/:id/activity.:format'
    activity.connect 'activity.:format', :id => nil
  end

  map.with_options :controller => 'repositories' do |repositories|
    repositories.with_options :conditions => {:method => :get} do |repository_views|
      repository_views.connect 'projects/:id/repository', :action => 'show'
      repository_views.connect 'projects/:id/repository/edit', :action => 'edit'
      repository_views.connect 'projects/:id/repository/statistics', :action => 'stats'
      repository_views.connect 'projects/:id/repository/revisions', :action => 'revisions'
      repository_views.connect 'projects/:id/repository/revisions.:format', :action => 'revisions'
      repository_views.connect 'projects/:id/repository/revisions/:rev', :action => 'revision'
      repository_views.connect 'projects/:id/repository/revisions/:rev/diff', :action => 'diff'
      repository_views.connect 'projects/:id/repository/revisions/:rev/diff.:format', :action => 'diff'
      repository_views.connect 'projects/:id/repository/revisions/:rev/raw/*path', :action => 'entry', :format => 'raw', :requirements => { :rev => /[a-z0-9\.\-_]+/ }
      repository_views.connect 'projects/:id/repository/revisions/:rev/:action/*path', :requirements => { :rev => /[a-z0-9\.\-_]+/ }
      repository_views.connect 'projects/:id/repository/raw/*path', :action => 'entry', :format => 'raw'
      # TODO: why the following route is required?
      repository_views.connect 'projects/:id/repository/entry/*path', :action => 'entry'
      repository_views.connect 'projects/:id/repository/:action/*path'
    end

    repositories.connect 'projects/:id/repository/:action', :conditions => {:method => :post}
  end
  
  map.resources :attachments, :only => [:show, :destroy]
  # additional routes for having the file name at the end of url
  map.connect 'attachments/:id/:filename', :controller => 'attachments', :action => 'show', :id => /\d+/, :filename => /.*/
  map.connect 'attachments/download/:id/:filename', :controller => 'attachments', :action => 'download', :id => /\d+/, :filename => /.*/

  map.resources :groups, :member => {:autocomplete_for_user => :get}
  map.group_users 'groups/:id/users', :controller => 'groups', :action => 'add_users', :id => /\d+/, :conditions => {:method => :post}
  map.group_user  'groups/:id/users/:user_id', :controller => 'groups', :action => 'remove_user', :id => /\d+/, :conditions => {:method => :delete}

  map.resources :trackers, :except => :show
  map.resources :issue_statuses, :except => :show, :collection => {:update_issue_done_ratio => :post}

  #left old routes at the bottom for backwards compat
  map.connect 'boards/:board_id/topics/:action/:id', :controller => 'messages'
  map.connect 'projects/:project_id/timelog/:action/:id', :controller => 'timelog', :project_id => /.+/
  map.with_options :controller => 'repositories' do |omap|
    omap.repositories_show 'repositories/browse/:id/*path', :action => 'browse'
    omap.repositories_changes 'repositories/changes/:id/*path', :action => 'changes'
    omap.repositories_diff 'repositories/diff/:id/*path', :action => 'diff'
    omap.repositories_entry 'repositories/entry/:id/*path', :action => 'entry'
    omap.repositories_entry 'repositories/annotate/:id/*path', :action => 'annotate'
    omap.connect 'repositories/revision/:id/:rev', :action => 'revision'
  end

  map.with_options :controller => 'sys' do |sys|
    sys.connect 'sys/projects.:format', :action => 'projects', :conditions => {:method => :get}
    sys.connect 'sys/projects/:id/repository.:format', :action => 'create_project_repository', :conditions => {:method => :post}
  end

  # Install the default route as the lowest priority.
  map.connect ':controller/:action/:id'
  map.connect 'robots.txt', :controller => 'welcome', :action => 'robots'
  # Used for OpenID
  map.root :controller => 'account', :action => 'login'
end
