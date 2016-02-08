require 'spec_helper'
require 'helpers/mock_alert'
require 'helpers/dsl_helper'
require 'interferon/destinations/datadog'

include Interferon

describe Interferon::Interferon do
  it "would not be dry run if only alert message changed" do
    alert1 = create_test_alert('name1', 'testquery', 'message1', true, 1000, 'test')
    alert2 = create_test_alert('name2', 'testquery', 'message2', true, 1000, 'test')

    expect(Interferon::Interferon.same_alerts_for_dry_run_purpose(alert1, alert2)).to be true
  end

  it "would be dry run if alert datadog query changed" do
    alert1 = create_test_alert('name1', 'testquery1', 'message1', true, 1000, 'test')
    alert2 = create_test_alert('name2', 'testquery2', 'message2', true, 1000, 'test')

    expect(Interferon::Interferon.same_alerts_for_dry_run_purpose(alert1, alert2)).to be false
  end

  context "dry_run_update_alerts_on_destination" do
    let(:the_existing_alerts) {mock_existing_alerts}
    let(:dest) {MockDest.new(the_existing_alerts)}
    before do
      allow_any_instance_of(MockAlert).to receive(:evaluate)
      allow(dest).to receive(:remove_alert_by_id)
      allow(dest).to receive(:report_stats)
    end

    it 'dry run does not re-run existing alerts' do
      alerts = mock_existing_alerts
      interferon = Interferon::Interferon.new(nil,nil,nil,nil)
      expect(dest).not_to receive(:create_alert)
      expect(dest).not_to receive(:remove_alert_by_id)
      
      interferon.dry_run_update_alerts_on_destination(dest, ['host'], [alerts['name1'], alerts['name2']], {})
    end

    it 'dry run runs added alerts' do
      alerts = mock_existing_alerts
      interferon = Interferon::Interferon.new(nil,nil,nil,nil)
      added = create_test_alert('name3', 'testquery3', '', true, 1000, true)
      expect(dest).to receive(:create_alert).once.and_call_original
      expect(dest).to receive(:remove_alert_by_id).with('[-dry-run-]name3').once
      
      interferon.dry_run_update_alerts_on_destination(dest, ['host'], [alerts['name1'], alerts['name2'], added], {})
    end

    it 'dry run runs updated alerts' do
      alerts = mock_existing_alerts
      interferon = Interferon::Interferon.new(nil,nil,nil,nil)
      added = create_test_alert('name1', 'testquery3', '', true, 1000, true)
      expect(dest).to receive(:create_alert).once.and_call_original
      expect(dest).to receive(:remove_alert_by_id).with('[-dry-run-]name1').once
      
      interferon.dry_run_update_alerts_on_destination(dest, ['host'], [alerts['name2'], added], {})
    end

    def mock_existing_alerts
      alert1 = create_test_alert('name1', 'testquery1', '', true, 1000, true)
      alert2 = create_test_alert('name2', 'testquery2', '', true, 1000, true)
      {'name1'=>alert1, 'name2'=>alert2}
    end

    class MockDest < Interferon::Destinations::Datadog
      @existing_alerts

      def initialize(the_existing_alerts)
        @existing_alerts = the_existing_alerts
      end

      def create_alert(alert, people)
        name = alert['name']
        [name, name]
      end

      def existing_alerts
        @existing_alerts
      end
    end
  end

  def create_test_alert(name, datadog_query, message, notify_no_data, no_data_timeframe, applies)
    alert_dsl = MockAlertDSL.new
    metric_dsl = MockMetricDSL.new
    metric_dsl.datadog_query(datadog_query)
    alert_dsl.metric(metric_dsl)
    alert_dsl.name(name)
    alert_dsl.message(message)
    alert_dsl.notify_no_data(notify_no_data)
    alert_dsl.no_data_timeframe(no_data_timeframe)
    alert_dsl.applies(applies)
    notify_dsl = MockNotifyDSL.new
    notify_dsl.groups(['a'])
    alert_dsl.notify(notify_dsl)
    MockAlert.new(alert_dsl)
  end
end
