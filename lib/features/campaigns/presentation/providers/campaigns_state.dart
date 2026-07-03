import 'package:equatable/equatable.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';
import 'package:ilithid/features/campaigns/domain/user_campaign.dart';

enum CampaignsStatus { initial, loading, success, error }

class CampaignsState extends Equatable {
  final CampaignsStatus status;
  final List<UserCampaign> campaigns;
  final Campaign? newCampaign;
  final String? errorMessage;

  const CampaignsState({
    required this.status,
    required this.campaigns,
    this.newCampaign,
    this.errorMessage,
  });

  factory CampaignsState.initial() {
    return const CampaignsState(status: CampaignsStatus.initial, campaigns: []);
  }

  factory CampaignsState.loading({
    List<UserCampaign> currentCampaigns = const [],
  }) {
    return CampaignsState(
      status: CampaignsStatus.loading,
      campaigns: currentCampaigns,
    );
  }

  factory CampaignsState.success(
    List<UserCampaign> campaigns, {
    Campaign? newCampaign,
  }) {
    return CampaignsState(
      status: CampaignsStatus.success,
      campaigns: campaigns,
      newCampaign: newCampaign,
    );
  }

  factory CampaignsState.error(
    String errorMessage, {
    List<UserCampaign> currentCampaigns = const [],
  }) {
    return CampaignsState(
      status: CampaignsStatus.error,
      campaigns: currentCampaigns,
      errorMessage: errorMessage,
    );
  }

  CampaignsState copyWith({
    CampaignsStatus? status,
    List<UserCampaign>? campaigns,
    Campaign? newCampaign,
    String? errorMessage,
  }) {
    return CampaignsState(
      status: status ?? this.status,
      campaigns: campaigns ?? this.campaigns,
      newCampaign: newCampaign ?? this.newCampaign,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, campaigns, newCampaign, errorMessage];
}
