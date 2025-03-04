# frozen_string_literal: true

require 'set'

# The workhorse of the EasyPost API, a Shipment is made up of a "to" and "from" Address, the Parcel
# being shipped, and any customs forms required for international deliveries.
class EasyPost::Shipment < EasyPost::Resource
  # Regenerate the rates of a Shipment.
  def regenerate_rates(params = {})
    response = EasyPost.make_request(:post, "#{url}/rerate", @api_key, params)
    refresh_from(response, @api_key)

    self
  end

  # Get the SmartRates of a Shipment.
  def get_smartrates # rubocop:disable Naming/AccessorMethodName
    response = EasyPost.make_request(:get, "#{url}/smartrate", @api_key)

    response.fetch('result', [])
  end

  # Buy a Shipment.
  def buy(params = {})
    if params.instance_of?(EasyPost::Rate)
      temp = params.clone
      params = {}
      params[:rate] = temp
    end

    response = EasyPost.make_request(:post, "#{url}/buy", @api_key, params)
    refresh_from(response, @api_key)

    self
  end

  # Insure a Shipment.
  def insure(params = {})
    if params.is_a?(Integer) || params.is_a?(Float)
      temp = params.clone
      params = {}
      params[:amount] = temp
    end

    response = EasyPost.make_request(:post, "#{url}/insure", @api_key, params)
    refresh_from(response, @api_key)

    self
  end

  # Refund a Shipment.
  def refund(params = {})
    response = EasyPost.make_request(:get, "#{url}/refund", @api_key, params)
    refresh_from(response, @api_key)

    self
  end

  # Convert the label format of a Shipment.
  def label(params = {})
    if params.is_a?(String)
      temp = params.clone
      params = {}
      params[:file_format] = temp
    end

    response = EasyPost.make_request(:get, "#{url}/label", @api_key, params)
    refresh_from(response, @api_key)

    self
  end

  # Get the lowest rate of a Shipment (can exclude by having `'!'` as the first element of your optional filter lists).
  def lowest_rate(carriers = [], services = [])
    EasyPost::Util.get_lowest_object_rate(self, carriers, services)
  end

  # Get the lowest smartrate of a Shipment.
  def lowest_smartrate(delivery_days, delivery_accuracy)
    smartrates = get_smartrates
    EasyPost::Shipment.get_lowest_smartrate(smartrates, delivery_days, delivery_accuracy)
  end

  # Get the lowest smartrate from a list of smartrates.
  def self.get_lowest_smartrate(smartrates, delivery_days, delivery_accuracy)
    valid_delivery_accuracy_values = Set[
      'percentile_50',
      'percentile_75',
      'percentile_85',
      'percentile_90',
      'percentile_95',
      'percentile_97',
      'percentile_99',
    ]
    lowest_smartrate = nil

    unless valid_delivery_accuracy_values.include?(delivery_accuracy.downcase)
      raise EasyPost::Error.new("Invalid delivery accuracy value, must be one of: #{valid_delivery_accuracy_values}")
    end

    smartrates.each do |rate|
      next if rate['time_in_transit'][delivery_accuracy] > delivery_days.to_i

      if lowest_smartrate.nil? || rate['rate'].to_f < lowest_smartrate['rate'].to_f
        lowest_smartrate = rate
      end
    end

    if lowest_smartrate.nil?
      raise EasyPost::Error.new('No rates found.')
    end

    lowest_smartrate
  end
end
