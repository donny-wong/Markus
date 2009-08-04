require File.join(File.dirname(__FILE__),'/../../lib/repo/repository_factory')
# Maintains group information for a given user on a specific assignment
class Group < ActiveRecord::Base
  
  after_create :set_repo_name, :build_repository
  
  has_many :groupings
  has_many :submissions, :through => :groupings
  has_many :student_memberships, :through => :groupings
  has_many :ta_memberships, :class_name => "TAMembership", :through =>
  :groupings
  has_many :assignments, :through => :groupings


  validates_presence_of :group_name
  validates_uniqueness_of :group_name
 
  # Validation happens only on create since this method iterates through
  # all assignments for all members. Might be costly when done also on 
  # updates. 
  # Separate checks are done when adding members; see invite() and add_member()

#  def validate_on_create
#    # validate each member does not belong in more than one group
#    assignments.each do |a|
#      student_memberships.each do |m|
#        user = m.user
#        g = user.group_for(a.id)  # user must not be in a group for this assignment
#        if m.valid? && g # user already in a group
#          errors.add_to_base("User '#{user.user_name}' already belongs in a group")
#        end
#      end
#
#      
#      if !a.group_assignment?
#        # check if groups can be formed on an assignment
#        errors.add_to_base("#{a.name} is not a group assignment")
#      else
#        # check if number of members meet the min and max criteria
#        num_members = student_memberships.length
#        min = a.group_min
#        max = a.group_max
#        if num_members < min
#          errors.add_to_base("You need at least #{min} members in the group.")
#        elsif num_members > max
#          errors.add_to_base("You can only have up to #{max} members in the group.")            
#        end
#     end
#   end
# end

  # Set repository name in database after a new group is created
  def set_repo_name
    self.repo_name="Group_" + self.id.to_s.rjust(3, "0")
    self.save # need to save!
  end

  # Returns the repository name for this group
  def repository_name
    return self.repo_name
  end
  
  def grouping_for_assignment(aid)
    return groupings.first(:conditions => {:assignment_id => aid})
  end
  
  # Returns true, if and only if the configured repository setup
  # allows for externally accessible repositories, in which case
  # file submissions via the Web interface are not permitted. For
  # now, this works for Subversion repositories only.
  def repository_external_commits_only?
    if IS_REPOSITORY_ADMIN && REPOSITORY_EXTERNAL_SUBMITS_ONLY
      case REPOSITORY_TYPE
        when "svn"
          retval = true
        else
          retval = false
      end
    else
      retval = false
    end
    return retval
  end
  
  # Returns the URL for externally accessible repos
  def repository_external_access_url
    return REPOSITORY_EXTERNAL_BASE_URL + "/" + repository_name
  end
  
  # Returns true if we are in admin mode
  def repository_admin?
    return IS_REPOSITORY_ADMIN
  end
  
  

 # Retrieve group object given user and assignment IDs.
 #  def self.find_group(user_id, assignment_id)
 #  user = User.find(user_id)
 #   return (user ? user.group_for(assignment_id) : nil)
 # end
  
  # Returns array of assignment files submitted by this user's group
  # def self.find_submission_files()
  #  return [] unless in_group?
  #  submitted_files = assignment_files.for_assignment
  #  # TODO get only the most recent submission for each file
  # end
  
  #######################################################################
  # Group functions
  
  # Returns 0 if this group has no members or 1 if it has only one member
  # def individual?
  #  return (members.empty? || members.length > 1) ? 0 : 1 
  # end
  
  # Return the maximum number of grace days this group can use
  # def grace_days
  #  condition = "group_number = ? and assignment_id = #{assignment_id}"
  #  members = Group.find(:all, :include => :user, :conditions => [condition, group_number])
  #  
  #  grace_day = User::GRACE_DAYS + 1
  #  members.each do |m|
  #    mgd = m.user.grace_days
  #    (grace_day = mgd) if mgd && mgd < grace_day
  #  end
  #  return grace_day
  #end
  
  def build_repository
    # Attempt to build the repository
    begin
      # create repositories and write permissions if and only if we are admin
      if IS_REPOSITORY_ADMIN
        Repository.get_class(REPOSITORY_TYPE).create(File.join(REPOSITORY_STORAGE, repository_name))
        if repository_admin?
          # Each admin user will have read and write permissions on each repo
          Admin.all.each do |admin|
            self.repo.add_user(admin.user_name, Repository::Permission::READ_WRITE)
          end
          # Each grader will have read and write permissions on each repo
          Ta.all.each do |ta|
            self.repo.add_user(ta.user_name, Repository::Permission::READ_WRITE)
          end
        end
      end
    rescue Exception => e
      raise e
    end
    return true
  end
  
  # Return a repository object, if possible
  def repo
    repo_loc = File.join(REPOSITORY_STORAGE, repository_name())
    if !IS_REPOSITORY_ADMIN

      if Repository.get_class(REPOSITORY_TYPE).repository_exists?(repo_loc)
        return Repository.get_class(REPOSITORY_TYPE).open(repo_loc, false) # use false as a second parameter, since we are not repo admin
      else
        raise "Repository not found and MarkUs not in authoritative mode!" # repository not found, and we are not repo-admin
      end
    else
      return Repository.get_class(REPOSITORY_TYPE).open(repo_loc)
    end
  end
end
