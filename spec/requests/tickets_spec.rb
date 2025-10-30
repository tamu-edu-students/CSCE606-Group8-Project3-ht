require 'rails_helper'

RSpec.describe "Tickets", type: :request do
  let(:category_option) { Ticket::CATEGORY_OPTIONS.first }
  let(:requester) { create(:user, role: :user) }
  let(:other_user) { create(:user, role: :user) }

  describe "POST /tickets" do
    before { sign_in(requester) }

    it "creates a ticket with the selected category and priority" do
      expect do
        post tickets_path, params: {
          ticket: {
            subject: "Printer broken",
            description: "The office printer is jammed.",
            status: :open,
            priority: :high,
            category: category_option
          }
        }
      end.to change(Ticket, :count).by(1)

      ticket = Ticket.order(:created_at).last
      expect(ticket.category).to eq(category_option)
      expect(ticket.priority).to eq("high")
      expect(response).to redirect_to(ticket_path(ticket))
      follow_redirect!
      expect(response.body).to include("Printer broken")
    end

    it "defaults priority to medium when not provided" do
      expect do
        post tickets_path, params: {
          ticket: {
            subject: "Need VPN access",
            description: "Cannot connect while travelling.",
            status: :open,
            category: category_option
          }
        }
      end.to change(Ticket, :count).by(1)

      ticket = Ticket.order(:created_at).last
      expect(ticket.priority).to eq("medium")
    end
  end

  describe "DELETE /tickets/:id" do
    let!(:ticket) { create(:ticket, requester: requester) }

    it "allows the requester to delete their open ticket" do
      sign_in(requester)

      expect do
        delete ticket_path(ticket)
      end.to change(Ticket, :count).by(-1)

      expect(response).to redirect_to(tickets_path)
      follow_redirect!
      expect(response.body).to include("Ticket deleted successfully.")
    end

    it "prevents other users from deleting the ticket" do
      sign_in(other_user)

      expect {
        delete ticket_path(ticket)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "prevents deleting a resolved ticket" do
      ticket.update!(status: :resolved)
      sign_in(requester)

      expect {
        delete ticket_path(ticket)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "PATCH /tickets/:id" do
    let!(:ticket) { create(:ticket, requester: requester, status: :open) }

    it "allows staff to update the ticket status" do
      agent = create(:user, :agent)
      sign_in(agent)

      patch ticket_path(ticket), params: { ticket: { status: :in_progress } }
      ticket.reload

      expect(ticket.status).to eq("in_progress")
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "does not allow the requester to modify status" do
      sign_in(requester)

      patch ticket_path(ticket), params: { ticket: { status: :resolved } }
      ticket.reload

      expect(ticket.status).to eq("open")
    end
  end

  describe "PATCH /tickets/:id/close" do
    let!(:ticket) { create(:ticket, requester: requester, status: :open) }

    it "resolves the ticket and sets closed_at" do
      sign_in(requester)

      patch close_ticket_path(ticket)
      ticket.reload

      expect(ticket.status).to eq("resolved")
      expect(ticket.closed_at).to be_present
      expect(response).to redirect_to(ticket_path(ticket))
    end

    it "prevents other users from closing the ticket" do
      sign_in(other_user)

      expect {
        patch close_ticket_path(ticket)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "prevents closing an already resolved ticket" do
      ticket.update!(status: :resolved)
      sign_in(requester)

      expect {
        patch close_ticket_path(ticket)
      }.to raise_error(Pundit::NotAuthorizedError)
    end
  end

  describe "GET /tickets/:id (privacy)" do
    let!(:ticket) { create(:ticket, requester: requester) }

    it "allows the requester (owner) to view their ticket" do
      sign_in(requester)
      get ticket_path(ticket)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ticket.subject)
    end

    it "prevents other requesters from viewing the ticket" do
      sign_in(other_user)
      expect {
        get ticket_path(ticket)
      }.to raise_error(Pundit::NotAuthorizedError)
    end

    it "allows an agent to view any ticket" do
      agent = create(:user, :agent)
      sign_in(agent)
      get ticket_path(ticket)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include(ticket.subject)
    end
  end
end
