require_relative '../resource'

module Convection
  module DSL
    module Template
      module Resource
        ##
        # DSL For EC2SecurityGroup rules
        ##
        module EC2SecurityGroup
          def ingress_rule(protocol = nil, port = nil, source = nil, &block)
            rule = Model::Template::Resource::EC2SecurityGroup::Rule.new("#{ name }IngressGroupRule", @template)
            rule.protocol = protocol unless protocol.nil?
            rule.from = port unless port.nil?
            rule.to = port unless port.nil?
            rule.source = source unless source.nil?

            rule.instance_exec(&block) if block
            security_group_ingress << rule
          end

          def egress_rule(protocol = nil, port = nil, destination = nil, &block)
            rule = Model::Template::Resource::EC2SecurityGroup::Rule.new("#{ name }EgressGroupRule", @template)
            rule.protocol = protocol unless protocol.nil?
            rule.from = port unless port.nil?
            rule.to = port unless port.nil?
            rule.destination = destination unless destination.nil?

            rule.instance_exec(&block) if block
            security_group_egress << rule
          end
        end
      end
    end
  end

  module Model
    class Template
      class Resource
        ##
        # AWS::EC2::SecurityGroup
        #
        # @example
        #   ec2_security_group 'SuperSecretSecurityGroup' do
        #     description 'This is a super secure group that nobody should know about.'
        #     vpc 'vpc-deadb33f'
        #   end
        ##
        class EC2SecurityGroup < Resource
          include DSL::Template::Resource::EC2SecurityGroup
          include Model::Mixin::Taggable

          attr_reader :security_group_ingress
          attr_reader :security_group_egress

          # @example Egress rule
          #   ec2_security_group 'SuperSecretSecurityGroup' do
          #     # other properties...
          #
          #     egress_rule :tcp, 443 do
          #       # The source CIDR block.
          #       destination '10.10.10.0/24'
          #     end
          #   end
          #
          # @example Ingress rule
          #   ec2_security_group 'SuperSecretSecurityGroup' do
          #     # other properties...
          #
          #     ingress_rule :tcp, 8080 do
          #       # The source security group ID.
          #       source_group stack.get('security-groups', 'HttpProxy')
          #     end
          #   end
          class Rule < Resource
            attribute :from
            attribute :to
            attribute :protocol

            attribute :source
            attribute :destination
            attribute :destination_group
            attribute :source_group
            attribute :source_group_owner

            def render
              {
                'IpProtocol' => Mixin::Protocol.lookup(protocol)
              }.tap do |rule|
                rule['FromPort'] = from unless from.nil?
                rule['ToPort'] = to unless to.nil?
                rule['CidrIp'] = source unless source.nil?
                rule['CidrIp'] = destination unless destination.nil?
                rule['DestinationSecurityGroupId'] = destination_group unless destination_group.nil?
                rule['SourceSecurityGroupId'] = source_group unless source_group.nil?
                rule['SourceSecurityGroupOwnerId'] = source_group_owner unless source_group_owner.nil?
              end
            end
          end

          type 'AWS::EC2::SecurityGroup'
          property :description, 'GroupDescription'
          property :vpc, 'VpcId'

          def initialize(*args)
            super

            @security_group_ingress = []
            @security_group_egress = []
          end

          def render(*args)
            super.tap do |resource|
              resource['Properties']['SecurityGroupIngress'] = security_group_ingress.map(&:render)
              resource['Properties']['SecurityGroupEgress'] = security_group_egress.map(&:render)
              render_tags(resource)
            end
          end
        end
      end
    end
  end
end
