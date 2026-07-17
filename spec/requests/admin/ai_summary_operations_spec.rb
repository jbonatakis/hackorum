require "rails_helper"

RSpec.describe "Admin summary operations", type: :request do
  it "rejects non-admin users" do
    sign_in_as(create(:user, admin: false))

    get admin_ai_summary_operations_path

    expect(response).to redirect_to(root_path)
  end

  it "shows operational status to administrators" do
    sign_in_as(create(:user, admin: true))
    create(:topic_summary_generation)

    get admin_ai_summary_operations_path

    expect(response).to have_http_status(:success)
    expect(response.body).to include("Summary Operations")
    expect(response.body).to include("Queued")
    expect(response.body).not_to include("OPENAI_API_KEY")
  end

  it "retries a failed generation" do
    sign_in_as(create(:user, admin: true))
    generation = create(:topic_summary_generation, state: "terminal_failed", attempts: 3)

    post retry_generation_admin_ai_summary_operations_path, params: { generation_id: generation.id }

    expect(response).to redirect_to(admin_ai_summary_operations_path)
    expect(generation.reload).to be_queued
  end
end
