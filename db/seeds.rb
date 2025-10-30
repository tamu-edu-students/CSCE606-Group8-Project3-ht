# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end
user = User.find_or_initialize_by(
  provider: "google_oauth2",
  uid:      "keeganasmith2003" # keep stable so it's idempotent
)

user.assign_attributes(
  email:    "keeganasmith2003@tamu.edu",
  name:     "Keegan Smith",
  image_url: "https://example.com/keegana.png",
  role:     :sysadmin
)

# (Optional) if you want seed tokens for local testing:
# user.access_token  = "seed-access-token"
# user.refresh_token = "seed-refresh-token"
# user.access_token_expires_at = 2.hours.from_now

user.save!
puts "Seeded user: #{user.email} (role: #{user.role})"


# === Settings ===
# Optional: enable round-robin assignment behavior your app checks via Setting.auto_round_robin?
Setting.set("assignment_strategy", "round_robin")

# === Users ===
# Your User enum is: enum :role, { user: 0, sysadmin: 1, staff: 2 }
def seed_user!(provider:, uid:, email:, name:, image_url:, role:)
  user = User.find_or_initialize_by(provider: provider, uid: uid)
  user.assign_attributes(email: email, name: name, image_url: image_url, role: role)
  user.save!
  user
end

requester  = seed_user!(
  provider:  "google_oauth2",
  uid:       "user1",
  email:     "dummy.requester@example.com",
  name:      "Dummy Requester 1",
  image_url: "https://example.com/requester.png",
  role:      :user
)

requester2 = seed_user!(
  provider:  "google_oauth2",
  uid:       "user2",
  email:     "dummy.requester2@example.com",
  name:      "Dummy Requester 2",
  image_url: "https://example.com/requester2.png",
  role:      :user
)

agent1 = seed_user!(
  provider:  "google_oauth2",
  uid:       "agent1",
  email:     "support.agent@example.com",
  name:      "Support Agent 1",
  image_url: "https://example.com/support_agent.png",
  role:      :staff
)

agent2 = seed_user!(
  provider:  "google_oauth2",
  uid:       "agent2",
  email:     "support.agent2@example.com",
  name:      "Support Agent 2",
  image_url: "https://example.com/support_agent2.png",
  role:      :staff
)

puts "Users seeded: #{User.count}"

# Tip for dev-only mock login (if you have /dev_login/:uid route):
# Visit /dev_login/user1, /dev_login/user2, /dev_login/agent1, /dev_login/agent2

# === Tickets ===
# Valid enums per model:
# status:   { open: 0, in_progress: 1, on_hold: 2, resolved: 3 }
# priority: { low: 0, medium: 1, high: 2 }
# category: must be in Ticket::CATEGORY_OPTIONS = ["Technical Issue","Account Access","Feature Request"]

tickets_attrs = [
  {
    subject:      "App crash on ticket submission",
    description:  "Every time I try to submit a ticket, the app crashes with a 500 error.",
    status:       :on_hold,
    priority:     :high,
    requester:    requester,
    assignee:     agent1,
    category:     "Technical Issue"
  },
  {
    subject:      "Cannot change account password",
    description:  "The password reset link redirects to an expired page.",
    status:       :in_progress,
    priority:     :medium,              # was :normal → fixed to :medium
    requester:    requester,
    assignee:     agent1,
    category:     "Account Access"      # was "Authentication" → fixed
  },
  {
    subject:      "Feature request: Email notifications for updates",
    description:  "Would be great if I could receive an email when the ticket status changes.",
    status:       :open,
    priority:     :low,
    requester:    requester,
    assignee:     nil,
    category:     "Feature Request"
  },
  {
    subject:      "Billing discrepancy for premium plan",
    description:  "Charged twice for the same month on my credit card statement.",
    status:       :resolved,
    priority:     :high,
    requester:    requester2,
    assignee:     agent2,
    category:     "Technical Issue"     # constrained to allowed options
    # closed_at will be auto-set by before_save since status is :resolved
  },
  {
    subject:      "Resolved: UI glitch on dashboard",
    description:  "Dashboard charts overlapped on Safari; fix deployed.",
    status:       :resolved,
    priority:     :medium,              # was :normal → fixed to :medium
    requester:    requester2,
    assignee:     agent2,
    category:     "Technical Issue"
  }
]

tickets = tickets_attrs.map do |attrs|
  t = Ticket.find_or_initialize_by(subject: attrs[:subject])
  t.assign_attributes(attrs)
  t.save!
  t
end

puts "Tickets seeded/updated: #{tickets.size} (Total in DB: #{Ticket.count})"

# === Comments ===
# Comment model requires: body (presence), visibility (presence, enum { public: 0, internal: 1 }),
# and belongs_to :author (User), :ticket.
def seed_comment!(ticket:, author:, body:, visibility:)
  Comment.find_or_create_by!(
    ticket: ticket,
    author: author,
    body:   body,
    visibility: visibility
  )
end

# Add a couple of example comments per some tickets (idempotent)
if tickets.any?
  t1 = tickets.find { |t| t.subject == "App crash on ticket submission" }
  t2 = tickets.find { |t| t.subject == "Cannot change account password" }

  if t1
    seed_comment!(
      ticket: t1,
      author: requester,
      body:   "Happens after I attach a screenshot. Without attachment it sometimes works.",
      visibility: :public
    )
    seed_comment!(
      ticket: t1,
      author: agent1,
      body:   "Replicated with attachments > 5MB. Investigating logs.",
      visibility: :internal
    )
  end

  if t2
    seed_comment!(
      ticket: t2,
      author: requester,
      body:   "Tried multiple browsers. Same result.",
      visibility: :public
    )
    seed_comment!(
      ticket: t2,
      author: agent1,
      body:   "Reset token generator rotated; patch queued for deploy.",
      visibility: :internal
    )
    seed_comment!(
      ticket: t2,
      author: agent1,
      body:   "Deployed fix. Please retry the reset link.",
      visibility: :public
    )
  end
end

puts "Comments seeded (Total in DB: #{Comment.count})"

puts "=============== Seeding complete ==========================="
