require 'rails_helper'

RSpec.describe AnalyticsSnapshot, type: :model do
  describe 'associations' do
    it 'belongs to a post target' do
      expect(build(:analytics_snapshot).post_target).to be_a(PostTarget)
    end

    it 'requires a post target' do
      snapshot = build(:analytics_snapshot, post_target: nil)

      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:post_target]).to include('must exist')
    end
  end

  describe 'validations' do
    it 'is valid with the factory attributes' do
      expect(build(:analytics_snapshot)).to be_valid
    end

    it 'requires fetched_at' do
      snapshot = build(:analytics_snapshot, fetched_at: nil)

      expect(snapshot).not_to be_valid
      expect(snapshot.errors[:fetched_at]).to include("can't be blank")
    end

    described_class::METRICS.each do |metric|
      it "rejects a negative #{metric} count" do
        snapshot = build(:analytics_snapshot, metric => -1)

        expect(snapshot).not_to be_valid
        expect(snapshot.errors[metric]).to include('must be greater than or equal to 0')
      end

      it "rejects a non-integer #{metric} count" do
        snapshot = build(:analytics_snapshot, metric => 1.5)

        expect(snapshot).not_to be_valid
        expect(snapshot.errors[metric]).to include('must be an integer')
      end

      it "defaults #{metric} to zero" do
        expect(described_class.new.public_send(metric)).to eq(0)
      end
    end
  end

  describe 'append-only behaviour' do
    it 'allows the initial create' do
      expect { create(:analytics_snapshot) }.to change(described_class, :count).by(1)
    end

    it 'refuses to update an existing row' do
      snapshot = create(:analytics_snapshot)

      expect { snapshot.update!(likes: 999) }
        .to raise_error(ActiveRecord::ReadOnlyRecord)
    end

    it 'records a new row per fetch rather than mutating the previous one' do
      target = create(:post_target)
      create(:analytics_snapshot, post_target: target, likes: 10, fetched_at: 2.hours.ago)
      create(:analytics_snapshot, post_target: target, likes: 25, fetched_at: 1.hour.ago)

      expect(target.analytics_snapshots.chronological.map(&:likes)).to eq([10, 25])
    end
  end

  describe '.chronological' do
    it 'orders oldest first' do
      target = create(:post_target)
      newer = create(:analytics_snapshot, post_target: target, fetched_at: 1.hour.ago)
      older = create(:analytics_snapshot, post_target: target, fetched_at: 3.hours.ago)

      expect(described_class.chronological).to eq([older, newer])
    end
  end
end
