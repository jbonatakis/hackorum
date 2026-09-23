require "rails_helper"

RSpec.describe AiSummary::SourceBuilder do
  it "serializes only sent messages in chronological order" do
    topic = create(:topic)
    later = create(:message, topic:, body: "Later", created_at: 2.hours.ago)
    earlier = create(:message, topic:, body: "Earlier", created_at: 3.hours.ago)
    create(:message, topic:, body: "Private pending", state: Message::STATE_PENDING, created_at: 1.hour.ago)

    result = described_class.call(topic)
    payload = JSON.parse(result.text)

    expect(result.message_ids).to eq([ earlier.id, later.id ])
    expect(payload.fetch("messages").pluck("untrusted_archived_content")).to eq(%w[Earlier Later])
    expect(result.fingerprint).to eq(Digest::SHA256.hexdigest(result.text))
  end

  it "includes bounded attachment metadata without attachment contents" do
    message = create(:message)
    attachment = create(:attachment, message:, file_name: "change.patch", body: Base64.strict_encode64("secret patch body"))

    payload = JSON.parse(described_class.call(message.topic).text)
    serialized_attachment = payload.dig("messages", 0, "attachments", 0)

    expect(serialized_attachment.fetch("file_name")).to eq("change.patch")
    expect(serialized_attachment.fetch("encoded_size_bytes")).to eq(attachment.body.bytesize)
    expect(payload.to_json).not_to include("secret patch body")
  end

  it "produces a stable fingerprint for unchanged source" do
    topic = create(:topic)
    create(:message, topic:)

    expect(described_class.call(topic).fingerprint).to eq(described_class.call(topic).fingerprint)
  end
end
