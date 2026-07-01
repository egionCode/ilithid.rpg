import 'package:equatable/equatable.dart';
import 'package:ilithid/features/campaigns/domain/campaign.dart';

class UserCampaign extends Equatable {
  final Campaign campaign;
  final String role;

  const UserCampaign({required this.campaign, required this.role});

  @override
  List<Object?> get props => [campaign, role];
}
