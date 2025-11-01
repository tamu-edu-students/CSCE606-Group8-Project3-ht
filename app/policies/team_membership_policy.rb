class TeamMembershipPolicy < ApplicationPolicy
  def create? = user.admin?
  def destroy? = user.admin?
end
