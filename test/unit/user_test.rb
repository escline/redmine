# Redmine - project management software
# Copyright (C) 2006-2011  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class UserTest < ActiveSupport::TestCase
  fixtures :users, :members, :projects, :roles, :member_roles, :auth_sources,
            :trackers, :issue_statuses,
            :projects_trackers,
            :watchers,
            :issue_categories, :enumerations, :issues,
            :journals, :journal_details,
            :groups_users,
            :enabled_modules,
            :workflows

  def setup
    @admin = User.find(1)
    @jsmith = User.find(2)
    @dlopper = User.find(3)
  end

  test 'object_daddy creation' do
    User.generate_with_protected!(:firstname => 'Testing connection')
    User.generate_with_protected!(:firstname => 'Testing connection')
    assert_equal 2, User.count(:all, :conditions => {:firstname => 'Testing connection'})
  end

  def test_truth
    assert_kind_of User, @jsmith
  end

  def test_mail_should_be_stripped
    u = User.new
    u.mail = " foo@bar.com  "
    assert_equal "foo@bar.com", u.mail
  end

  def test_mail_validation
    u = User.new
    u.mail = ''
    assert !u.valid?
    assert_equal I18n.translate('activerecord.errors.messages.blank'), u.errors[:mail].join(",")
  end

  def test_create
    user = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")

    user.login = "jsmith"
    user.password, user.password_confirmation = "password", "password"
    # login uniqueness
    assert !user.save
    assert_equal 1, user.errors.count

    user.login = "newuser"
    user.password, user.password_confirmation = "passwd", "password"
    # password confirmation
    assert !user.save
    assert_equal 1, user.errors.count

    user.password, user.password_confirmation = "password", "password"
    assert user.save
  end

  context "User#before_create" do
    should "set the mail_notification to the default Setting" do
      @user1 = User.generate_with_protected!
      assert_equal 'only_my_events', @user1.mail_notification

      with_settings :default_notification_option => 'all' do
        @user2 = User.generate_with_protected!
        assert_equal 'all', @user2.mail_notification
      end
    end
  end

  context "User.login" do
    should "be case-insensitive." do
      u = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
      u.login = 'newuser'
      u.password, u.password_confirmation = "password", "password"
      assert u.save

      u = User.new(:firstname => "Similar", :lastname => "User", :mail => "similaruser@somenet.foo")
      u.login = 'NewUser'
      u.password, u.password_confirmation = "password", "password"
      assert !u.save
      assert_equal I18n.translate('activerecord.errors.messages.taken'), u.errors[:login].join(",")
    end
  end

  def test_mail_uniqueness_should_not_be_case_sensitive
    u = User.new(:firstname => "new", :lastname => "user", :mail => "newuser@somenet.foo")
    u.login = 'newuser1'
    u.password, u.password_confirmation = "password", "password"
    assert u.save

    u = User.new(:firstname => "new", :lastname => "user", :mail => "newUser@Somenet.foo")
    u.login = 'newuser2'
    u.password, u.password_confirmation = "password", "password"
    assert !u.save
    assert_equal I18n.translate('activerecord.errors.messages.taken'), u.errors[:mail].join(",")
  end

  def test_update
    assert_equal "admin", @admin.login
    @admin.login = "john"
    assert @admin.save, @admin.errors.full_messages.join("; ")
    @admin.reload
    assert_equal "john", @admin.login
  end

  def test_destroy_should_delete_members_and_roles
    members = Member.find_all_by_user_id(2)
    ms = members.size
    rs = members.collect(&:roles).flatten.size

    assert_difference 'Member.count', - ms do
      assert_difference 'MemberRole.count', - rs do
        User.find(2).destroy
      end
    end

    assert_nil User.find_by_id(2)
    assert Member.find_all_by_user_id(2).empty?
  end

  def test_destroy_should_update_attachments
    attachment = Attachment.create!(:container => Project.find(1),
      :file => uploaded_test_file("testfile.txt", "text/plain"),
      :author_id => 2)

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, attachment.reload.author
  end

  def test_destroy_should_update_comments
    comment = Comment.create!(
      :commented => News.create!(:project_id => 1, :author_id => 1, :title => 'foo', :description => 'foo'),
      :author => User.find(2),
      :comments => 'foo'
    )

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, comment.reload.author
  end

  def test_destroy_should_update_issues
    issue = Issue.create!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, issue.reload.author
  end

  def test_destroy_should_unassign_issues
    issue = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :subject => 'foo', :assigned_to_id => 2)

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil issue.reload.assigned_to
  end

  def test_destroy_should_update_journals
    issue = Issue.create!(:project_id => 1, :author_id => 2, :tracker_id => 1, :subject => 'foo')
    issue.init_journal(User.find(2), "update")
    issue.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, issue.journals.first.reload.user
  end

  def test_destroy_should_update_journal_details_old_value
    issue = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :subject => 'foo', :assigned_to_id => 2)
    issue.init_journal(User.find(1), "update")
    issue.assigned_to_id = nil
    assert_difference 'JournalDetail.count' do
      issue.save!
    end
    journal_detail = JournalDetail.first(:order => 'id DESC')
    assert_equal '2', journal_detail.old_value

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous.id.to_s, journal_detail.reload.old_value
  end

  def test_destroy_should_update_journal_details_value
    issue = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :subject => 'foo')
    issue.init_journal(User.find(1), "update")
    issue.assigned_to_id = 2
    assert_difference 'JournalDetail.count' do
      issue.save!
    end
    journal_detail = JournalDetail.first(:order => 'id DESC')
    assert_equal '2', journal_detail.value

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous.id.to_s, journal_detail.reload.value
  end

  def test_destroy_should_update_messages
    board = Board.create!(:project_id => 1, :name => 'Board', :description => 'Board')
    message = Message.create!(:board_id => board.id, :author_id => 2, :subject => 'foo', :content => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, message.reload.author
  end

  def test_destroy_should_update_news
    news = News.create!(:project_id => 1, :author_id => 2, :title => 'foo', :description => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, news.reload.author
  end

  def test_destroy_should_delete_private_queries
    query = Query.new(:name => 'foo', :is_public => false)
    query.project_id = 1
    query.user_id = 2
    query.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil Query.find_by_id(query.id)
  end

  def test_destroy_should_update_public_queries
    query = Query.new(:name => 'foo', :is_public => true)
    query.project_id = 1
    query.user_id = 2
    query.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, query.reload.user
  end

  def test_destroy_should_update_time_entries
    entry = TimeEntry.new(:hours => '2', :spent_on => Date.today, :activity => TimeEntryActivity.create!(:name => 'foo'))
    entry.project_id = 1
    entry.user_id = 2
    entry.save!

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, entry.reload.user
  end

  def test_destroy_should_delete_tokens
    token = Token.create!(:user_id => 2, :value => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil Token.find_by_id(token.id)
  end

  def test_destroy_should_delete_watchers
    issue = Issue.create!(:project_id => 1, :author_id => 1, :tracker_id => 1, :subject => 'foo')
    watcher = Watcher.create!(:user_id => 2, :watchable => issue)

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil Watcher.find_by_id(watcher.id)
  end

  def test_destroy_should_update_wiki_contents
    wiki_content = WikiContent.create!(
      :text => 'foo',
      :author_id => 2,
      :page => WikiPage.create!(:title => 'Foo', :wiki => Wiki.create!(:project_id => 1, :start_page => 'Start'))
    )
    wiki_content.text = 'bar'
    assert_difference 'WikiContent::Version.count' do
      wiki_content.save!
    end

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_equal User.anonymous, wiki_content.reload.author
    wiki_content.versions.each do |version|
      assert_equal User.anonymous, version.reload.author
    end
  end

  def test_destroy_should_nullify_issue_categories
    category = IssueCategory.create!(:project_id => 1, :assigned_to_id => 2, :name => 'foo')

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil category.reload.assigned_to_id
  end

  def test_destroy_should_nullify_changesets
    changeset = Changeset.create!(
      :repository => Repository::Subversion.create!(
        :project_id => 1,
        :url => 'file:///var/svn'
      ),
      :revision => '12',
      :committed_on => Time.now,
      :committer => 'jsmith'
      )
    assert_equal 2, changeset.user_id

    User.find(2).destroy
    assert_nil User.find_by_id(2)
    assert_nil changeset.reload.user_id
  end

  def test_anonymous_user_should_not_be_destroyable
    assert_no_difference 'User.count' do
      assert_equal false, User.anonymous.destroy
    end
  end

  def test_validate_login_presence
    @admin.login = ""
    assert !@admin.save
    assert_equal 1, @admin.errors.count
  end

  def test_validate_mail_notification_inclusion
    u = User.new
    u.mail_notification = 'foo'
    u.save
    assert_not_nil u.errors[:mail_notification]
  end

  context "User#try_to_login" do
    should "fall-back to case-insensitive if user login is not found as-typed." do
      user = User.try_to_login("AdMin", "admin")
      assert_kind_of User, user
      assert_equal "admin", user.login
    end

    should "select the exact matching user first" do
      case_sensitive_user = User.generate_with_protected!(
                                   :login => 'changed', :password => 'admin',
                                   :password_confirmation => 'admin')
      # bypass validations to make it appear like existing data
      case_sensitive_user.update_attribute(:login, 'ADMIN')

      user = User.try_to_login("ADMIN", "admin")
      assert_kind_of User, user
      assert_equal "ADMIN", user.login

    end
  end

  def test_password
    user = User.try_to_login("admin", "admin")
    assert_kind_of User, user
    assert_equal "admin", user.login
    user.password = "hello"
    assert user.save

    user = User.try_to_login("admin", "hello")
    assert_kind_of User, user
    assert_equal "admin", user.login
  end

  def test_validate_password_length
    with_settings :password_min_length => '100' do
      user = User.new(:firstname => "new100", :lastname => "user100", :mail => "newuser100@somenet.foo")
      user.login = "newuser100"
      user.password, user.password_confirmation = "password100", "password100"
      assert !user.save
      assert_equal 1, user.errors.count
    end
  end

  def test_name_format
    assert_equal 'Smith, John', @jsmith.name(:lastname_coma_firstname)
    Setting.user_format = :firstname_lastname
    assert_equal 'John Smith', @jsmith.reload.name
    Setting.user_format = :username
    assert_equal 'jsmith', @jsmith.reload.name
  end
  
  def test_fields_for_order_statement_should_return_fields_according_user_format_setting
    with_settings :user_format => 'lastname_coma_firstname' do
      assert_equal ['users.lastname', 'users.firstname', 'users.id'], User.fields_for_order_statement
    end
  end
  
  def test_fields_for_order_statement_width_table_name_should_prepend_table_name
    with_settings :user_format => 'lastname_firstname' do
      assert_equal ['authors.lastname', 'authors.firstname', 'authors.id'], User.fields_for_order_statement('authors')
    end
  end
  
  def test_fields_for_order_statement_with_blank_format_should_return_default
    with_settings :user_format => '' do
      assert_equal ['users.firstname', 'users.lastname', 'users.id'], User.fields_for_order_statement
    end
  end
  
  def test_fields_for_order_statement_with_invalid_format_should_return_default
    with_settings :user_format => 'foo' do
      assert_equal ['users.firstname', 'users.lastname', 'users.id'], User.fields_for_order_statement
    end
  end

  def test_lock
    user = User.try_to_login("jsmith", "jsmith")
    assert_equal @jsmith, user

    @jsmith.status = User::STATUS_LOCKED
    assert @jsmith.save

    user = User.try_to_login("jsmith", "jsmith")
    assert_equal nil, user
  end

  context ".try_to_login" do
    context "with good credentials" do
      should "return the user" do
        user = User.try_to_login("admin", "admin")
        assert_kind_of User, user
        assert_equal "admin", user.login
      end
    end

    context "with wrong credentials" do
      should "return nil" do
        assert_nil User.try_to_login("admin", "foo")
      end
    end
  end

  if ldap_configured?
    context "#try_to_login using LDAP" do
      context "with failed connection to the LDAP server" do
        should "return nil" do
          @auth_source = AuthSourceLdap.find(1)
          AuthSource.any_instance.stubs(:initialize_ldap_con).raises(Net::LDAP::LdapError, 'Cannot connect')

          assert_equal nil, User.try_to_login('edavis', 'wrong')
        end
      end

      context "with an unsuccessful authentication" do
        should "return nil" do
          assert_equal nil, User.try_to_login('edavis', 'wrong')
        end
      end

      context "on the fly registration" do
        setup do
          @auth_source = AuthSourceLdap.find(1)
        end

        context "with a successful authentication" do
          should "create a new user account if it doesn't exist" do
            assert_difference('User.count') do
              user = User.try_to_login('edavis', '123456')
              assert !user.admin?
            end
          end

          should "retrieve existing user" do
            user = User.try_to_login('edavis', '123456')
            user.admin = true
            user.save!

            assert_no_difference('User.count') do
              user = User.try_to_login('edavis', '123456')
              assert user.admin?
            end
          end
        end
      end
    end

  else
    puts "Skipping LDAP tests."
  end

  def test_create_anonymous
    AnonymousUser.delete_all
    anon = User.anonymous
    assert !anon.new_record?
    assert_kind_of AnonymousUser, anon
  end

  def test_ensure_single_anonymous_user
    AnonymousUser.delete_all
    anon1 = User.anonymous
    assert !anon1.new_record?
    assert_kind_of AnonymousUser, anon1
    anon2 = AnonymousUser.create(
                :lastname => 'Anonymous', :firstname => '',
                :mail => '', :login => '', :status => 0)
    assert_equal 1, anon2.errors.count
  end

  should_have_one :rss_token

  def test_rss_key
    assert_nil @jsmith.rss_token
    key = @jsmith.rss_key
    assert_equal 40, key.length

    @jsmith.reload
    assert_equal key, @jsmith.rss_key
  end


  should_have_one :api_token

  context "User#api_key" do
    should "generate a new one if the user doesn't have one" do
      user = User.generate_with_protected!(:api_token => nil)
      assert_nil user.api_token

      key = user.api_key
      assert_equal 40, key.length
      user.reload
      assert_equal key, user.api_key
    end

    should "return the existing api token value" do
      user = User.generate_with_protected!
      token = Token.generate!(:action => 'api')
      user.api_token = token
      assert user.save

      assert_equal token.value, user.api_key
    end
  end

  context "User#find_by_api_key" do
    should "return nil if no matching key is found" do
      assert_nil User.find_by_api_key('zzzzzzzzz')
    end

    should "return nil if the key is found for an inactive user" do
      user = User.generate_with_protected!(:status => User::STATUS_LOCKED)
      token = Token.generate!(:action => 'api')
      user.api_token = token
      user.save

      assert_nil User.find_by_api_key(token.value)
    end

    should "return the user if the key is found for an active user" do
      user = User.generate_with_protected!(:status => User::STATUS_ACTIVE)
      token = Token.generate!(:action => 'api')
      user.api_token = token
      user.save

      assert_equal user, User.find_by_api_key(token.value)
    end
  end

  def test_roles_for_project
    # user with a role
    roles = @jsmith.roles_for_project(Project.find(1))
    assert_kind_of Role, roles.first
    assert_equal "Manager", roles.first.name

    # user with no role
    assert_nil @dlopper.roles_for_project(Project.find(2)).detect {|role| role.member?}
  end

  def test_projects_by_role_for_user_with_role
    user = User.find(2)
    assert_kind_of Hash, user.projects_by_role
    assert_equal 2, user.projects_by_role.size
    assert_equal [1,5], user.projects_by_role[Role.find(1)].collect(&:id).sort
    assert_equal [2], user.projects_by_role[Role.find(2)].collect(&:id).sort
  end

  def test_projects_by_role_for_user_with_no_role
    user = User.generate!
    assert_equal({}, user.projects_by_role)
  end

  def test_projects_by_role_for_anonymous
    assert_equal({}, User.anonymous.projects_by_role)
  end

  def test_valid_notification_options
    # without memberships
    assert_equal 5, User.find(7).valid_notification_options.size
    # with memberships
    assert_equal 6, User.find(2).valid_notification_options.size
  end

  def test_valid_notification_options_class_method
    assert_equal 5, User.valid_notification_options.size
    assert_equal 5, User.valid_notification_options(User.find(7)).size
    assert_equal 6, User.valid_notification_options(User.find(2)).size
  end

  def test_mail_notification_all
    @jsmith.mail_notification = 'all'
    @jsmith.notified_project_ids = []
    @jsmith.save
    @jsmith.reload
    assert @jsmith.projects.first.recipients.include?(@jsmith.mail)
  end

  def test_mail_notification_selected
    @jsmith.mail_notification = 'selected'
    @jsmith.notified_project_ids = [1]
    @jsmith.save
    @jsmith.reload
    assert Project.find(1).recipients.include?(@jsmith.mail)
  end

  def test_mail_notification_only_my_events
    @jsmith.mail_notification = 'only_my_events'
    @jsmith.notified_project_ids = []
    @jsmith.save
    @jsmith.reload
    assert !@jsmith.projects.first.recipients.include?(@jsmith.mail)
  end

  def test_comments_sorting_preference
    assert !@jsmith.wants_comments_in_reverse_order?
    @jsmith.pref.comments_sorting = 'asc'
    assert !@jsmith.wants_comments_in_reverse_order?
    @jsmith.pref.comments_sorting = 'desc'
    assert @jsmith.wants_comments_in_reverse_order?
  end

  def test_find_by_mail_should_be_case_insensitive
    u = User.find_by_mail('JSmith@somenet.foo')
    assert_not_nil u
    assert_equal 'jsmith@somenet.foo', u.mail
  end

  def test_random_password
    u = User.new
    u.random_password
    assert !u.password.blank?
    assert !u.password_confirmation.blank?
  end

  context "#change_password_allowed?" do
    should "be allowed if no auth source is set" do
      user = User.generate_with_protected!
      assert user.change_password_allowed?
    end

    should "delegate to the auth source" do
      user = User.generate_with_protected!

      allowed_auth_source = AuthSource.generate!
      def allowed_auth_source.allow_password_changes?; true; end

      denied_auth_source = AuthSource.generate!
      def denied_auth_source.allow_password_changes?; false; end

      assert user.change_password_allowed?

      user.auth_source = allowed_auth_source
      assert user.change_password_allowed?, "User not allowed to change password, though auth source does"

      user.auth_source = denied_auth_source
      assert !user.change_password_allowed?, "User allowed to change password, though auth source does not"
    end

  end

  context "#allowed_to?" do
    context "with a unique project" do
      should "return false if project is archived" do
        project = Project.find(1)
        Project.any_instance.stubs(:status).returns(Project::STATUS_ARCHIVED)
        assert ! @admin.allowed_to?(:view_issues, Project.find(1))
      end

      should "return false if related module is disabled" do
        project = Project.find(1)
        project.enabled_module_names = ["issue_tracking"]
        assert @admin.allowed_to?(:add_issues, project)
        assert ! @admin.allowed_to?(:view_wiki_pages, project)
      end

      should "authorize nearly everything for admin users" do
        project = Project.find(1)
        assert ! @admin.member_of?(project)
        %w(edit_issues delete_issues manage_news manage_documents manage_wiki).each do |p|
          assert @admin.allowed_to?(p.to_sym, project)
        end
      end

      should "authorize normal users depending on their roles" do
        project = Project.find(1)
        assert @jsmith.allowed_to?(:delete_messages, project)    #Manager
        assert ! @dlopper.allowed_to?(:delete_messages, project) #Developper
      end
    end

    context "with multiple projects" do
      should "return false if array is empty" do
        assert ! @admin.allowed_to?(:view_project, [])
      end

      should "return true only if user has permission on all these projects" do
        assert @admin.allowed_to?(:view_project, Project.all)
        assert ! @dlopper.allowed_to?(:view_project, Project.all) #cannot see Project(2)
        assert @jsmith.allowed_to?(:edit_issues, @jsmith.projects) #Manager or Developer everywhere
        assert ! @jsmith.allowed_to?(:delete_issue_watchers, @jsmith.projects) #Dev cannot delete_issue_watchers
      end

      should "behave correctly with arrays of 1 project" do
        assert ! User.anonymous.allowed_to?(:delete_issues, [Project.first])
      end
    end

    context "with options[:global]" do
      should "authorize if user has at least one role that has this permission" do
        @dlopper2 = User.find(5) #only Developper on a project, not Manager anywhere
        @anonymous = User.find(6)
        assert @jsmith.allowed_to?(:delete_issue_watchers, nil, :global => true)
        assert ! @dlopper2.allowed_to?(:delete_issue_watchers, nil, :global => true)
        assert @dlopper2.allowed_to?(:add_issues, nil, :global => true)
        assert ! @anonymous.allowed_to?(:add_issues, nil, :global => true)
        assert @anonymous.allowed_to?(:view_issues, nil, :global => true)
      end
    end
  end

  context "User#notify_about?" do
    context "Issues" do
      setup do
        @project = Project.find(1)
        @author = User.generate_with_protected!
        @assignee = User.generate_with_protected!
        @issue = Issue.generate_for_project!(@project, :assigned_to => @assignee, :author => @author)
      end

      should "be true for a user with :all" do
        @author.update_attribute(:mail_notification, 'all')
        assert @author.notify_about?(@issue)
      end

      should "be false for a user with :none" do
        @author.update_attribute(:mail_notification, 'none')
        assert ! @author.notify_about?(@issue)
      end

      should "be false for a user with :only_my_events and isn't an author, creator, or assignee" do
        @user = User.generate_with_protected!(:mail_notification => 'only_my_events')
        Member.create!(:user => @user, :project => @project, :role_ids => [1])
        assert ! @user.notify_about?(@issue)
      end

      should "be true for a user with :only_my_events and is the author" do
        @author.update_attribute(:mail_notification, 'only_my_events')
        assert @author.notify_about?(@issue)
      end

      should "be true for a user with :only_my_events and is the assignee" do
        @assignee.update_attribute(:mail_notification, 'only_my_events')
        assert @assignee.notify_about?(@issue)
      end

      should "be true for a user with :only_assigned and is the assignee" do
        @assignee.update_attribute(:mail_notification, 'only_assigned')
        assert @assignee.notify_about?(@issue)
      end

      should "be false for a user with :only_assigned and is not the assignee" do
        @author.update_attribute(:mail_notification, 'only_assigned')
        assert ! @author.notify_about?(@issue)
      end

      should "be true for a user with :only_owner and is the author" do
        @author.update_attribute(:mail_notification, 'only_owner')
        assert @author.notify_about?(@issue)
      end

      should "be false for a user with :only_owner and is not the author" do
        @assignee.update_attribute(:mail_notification, 'only_owner')
        assert ! @assignee.notify_about?(@issue)
      end

      should "be true for a user with :selected and is the author" do
        @author.update_attribute(:mail_notification, 'selected')
        assert @author.notify_about?(@issue)
      end

      should "be true for a user with :selected and is the assignee" do
        @assignee.update_attribute(:mail_notification, 'selected')
        assert @assignee.notify_about?(@issue)
      end

      should "be false for a user with :selected and is not the author or assignee" do
        @user = User.generate_with_protected!(:mail_notification => 'selected')
        Member.create!(:user => @user, :project => @project, :role_ids => [1])
        assert ! @user.notify_about?(@issue)
      end
    end

    context "other events" do
      should 'be added and tested'
    end
  end

  def test_salt_unsalted_passwords
    # Restore a user with an unsalted password
    user = User.find(1)
    user.salt = nil
    user.hashed_password = User.hash_password("unsalted")
    user.save!

    User.salt_unsalted_passwords!

    user.reload
    # Salt added
    assert !user.salt.blank?
    # Password still valid
    assert user.check_password?("unsalted")
    assert_equal user, User.try_to_login(user.login, "unsalted")
  end

  if Object.const_defined?(:OpenID)

  def test_setting_identity_url
    normalized_open_id_url = 'http://example.com/'
    u = User.new( :identity_url => 'http://example.com/' )
    assert_equal normalized_open_id_url, u.identity_url
  end

  def test_setting_identity_url_without_trailing_slash
    normalized_open_id_url = 'http://example.com/'
    u = User.new( :identity_url => 'http://example.com' )
    assert_equal normalized_open_id_url, u.identity_url
  end

  def test_setting_identity_url_without_protocol
    normalized_open_id_url = 'http://example.com/'
    u = User.new( :identity_url => 'example.com' )
    assert_equal normalized_open_id_url, u.identity_url
  end

  def test_setting_blank_identity_url
    u = User.new( :identity_url => 'example.com' )
    u.identity_url = ''
    assert u.identity_url.blank?
  end

  def test_setting_invalid_identity_url
    u = User.new( :identity_url => 'this is not an openid url' )
    assert u.identity_url.blank?
  end

  else
    puts "Skipping openid tests."
  end

end
