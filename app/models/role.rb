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

class Role < ActiveRecord::Base
  # Built-in roles
  BUILTIN_NON_MEMBER = 1
  BUILTIN_ANONYMOUS  = 2

  ISSUES_VISIBILITY_OPTIONS = [
    ['all', :label_issues_visibility_all],
    ['default', :label_issues_visibility_public],
    ['own', :label_issues_visibility_own]
  ]

  scope :givable, { :conditions => "builtin = 0", :order => 'position' }
  scope :builtin, lambda { |*args|
    compare = 'not' if args.first == true
    { :conditions => "#{compare} builtin = 0" }
  }

  before_destroy :check_deletable
  has_many :workflows, :dependent => :delete_all do
    def copy(source_role)
      Workflow.copy(nil, source_role, nil, proxy_owner)
    end
  end

  has_many :member_roles, :dependent => :destroy
  has_many :members, :through => :member_roles
  acts_as_list

  serialize :permissions, Array
  attr_protected :builtin

  validates_presence_of :name
  validates_uniqueness_of :name
  validates_length_of :name, :maximum => 30
  validates_inclusion_of :issues_visibility,
    :in => ISSUES_VISIBILITY_OPTIONS.collect(&:first),
    :if => lambda {|role| role.respond_to?(:issues_visibility)}

  def permissions
    read_attribute(:permissions) || []
  end

  def permissions=(perms)
    perms = perms.collect {|p| p.to_sym unless p.blank? }.compact.uniq if perms
    write_attribute(:permissions, perms)
  end

  def add_permission!(*perms)
    self.permissions = [] unless permissions.is_a?(Array)

    permissions_will_change!
    perms.each do |p|
      p = p.to_sym
      permissions << p unless permissions.include?(p)
    end
    save!
  end

  def remove_permission!(*perms)
    return unless permissions.is_a?(Array)
    permissions_will_change!
    perms.each { |p| permissions.delete(p.to_sym) }
    save!
  end

  # Returns true if the role has the given permission
  def has_permission?(perm)
    !permissions.nil? && permissions.include?(perm.to_sym)
  end

  def <=>(role)
    role ? position <=> role.position : -1
  end

  def to_s
    name
  end

  def name
    case builtin
    when 1; l(:label_role_non_member, :default => read_attribute(:name))
    when 2; l(:label_role_anonymous,  :default => read_attribute(:name))
    else; read_attribute(:name)
    end
  end

  # Return true if the role is a builtin role
  def builtin?
    self.builtin != 0
  end

  # Return true if the role is a project member role
  def member?
    !self.builtin?
  end

  # Return true if role is allowed to do the specified action
  # action can be:
  # * a parameter-like Hash (eg. :controller => 'projects', :action => 'edit')
  # * a permission Symbol (eg. :edit_project)
  def allowed_to?(action)
    if action.is_a? Hash
      allowed_actions.include? "#{action[:controller]}/#{action[:action]}"
    else
      allowed_permissions.include? action
    end
  end

  # Return all the permissions that can be given to the role
  def setable_permissions
    setable_permissions = Redmine::AccessControl.permissions - Redmine::AccessControl.public_permissions
    setable_permissions -= Redmine::AccessControl.members_only_permissions if self.builtin == BUILTIN_NON_MEMBER
    setable_permissions -= Redmine::AccessControl.loggedin_only_permissions if self.builtin == BUILTIN_ANONYMOUS
    setable_permissions
  end

  # Find all the roles that can be given to a project member
  def self.find_all_givable
    find(:all, :conditions => {:builtin => 0}, :order => 'position')
  end

  # Return the builtin 'non member' role.  If the role doesn't exist,
  # it will be created on the fly.
  def self.non_member
    find_or_create_system_role(BUILTIN_NON_MEMBER, 'Non member')
  end

  # Return the builtin 'anonymous' role.  If the role doesn't exist,
  # it will be created on the fly.
  def self.anonymous
    find_or_create_system_role(BUILTIN_ANONYMOUS, 'Anonymous')
  end

private

  def allowed_permissions
    @allowed_permissions ||= permissions + Redmine::AccessControl.public_permissions.collect {|p| p.name}
  end

  def allowed_actions
    @actions_allowed ||= allowed_permissions.inject([]) { |actions, permission| actions += Redmine::AccessControl.allowed_actions(permission) }.flatten
  end

  def check_deletable
    raise "Can't delete role" if members.any?
    raise "Can't delete builtin role" if builtin?
  end

  def self.find_or_create_system_role(builtin, name)
    role = first(:conditions => {:builtin => builtin})
    if role.nil?
      role = create(:name => name, :position => 0) do |r|
        r.builtin = builtin
      end
      raise "Unable to create the #{name} role." if role.new_record?
    end
    role
  end
end
