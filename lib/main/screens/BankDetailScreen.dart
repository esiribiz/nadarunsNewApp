import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:http/http.dart';
import '../../extensions/extension_util/int_extensions.dart';
import '../../extensions/extension_util/string_extensions.dart';
import '../../extensions/extension_util/widget_extensions.dart';

import '../../extensions/app_button.dart';
import '../../extensions/app_text_field.dart';
import '../../extensions/common.dart';
import '../../extensions/shared_pref.dart';
import '../../extensions/system_utils.dart';
import '../../extensions/text_styles.dart';
import '../../main.dart';
import '../components/CommonScaffoldComponent.dart';
import '../models/LoginResponse.dart';
import '../network/NetworkUtils.dart';
import '../network/RestApis.dart';
import '../utils/Common.dart';
import '../utils/Constants.dart';
import '../utils/dynamic_theme.dart';

class BankDetailScreen extends StatefulWidget {
  final bool? isWallet;

  BankDetailScreen({this.isWallet = false});

  @override
  _BankDetailScreenState createState() => _BankDetailScreenState();
}

class _BankDetailScreenState extends State<BankDetailScreen> {
  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  TextEditingController bankNameCon = TextEditingController();
  TextEditingController nameCon = TextEditingController();
  TextEditingController bankSwiftCon = TextEditingController();
  TextEditingController bankIbanCon = TextEditingController();

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    getBankDetail();
  }

  getBankDetail() async {
    appStore.setLoading(true);
    await getUserDetail(getIntAsync(USER_ID))
        .then((value) {
          appStore.setLoading(false);
          if (value.userBankAccount != null) {
            bankNameCon.text = value.userBankAccount!.bankName.validate();
            nameCon.text = value.userBankAccount!.accountHolderName.validate();
            bankIbanCon.text = value.userBankAccount!.bankIban.validate(
              value: value.userBankAccount!.accountNumber.validate(),
            );
            bankSwiftCon.text = value.userBankAccount!.bankSwift.validate(
              value: value.userBankAccount!.bankCode.validate(),
            );
            setState(() {});
          }
        })
        .then((value) {
          appStore.setLoading(false);
        });
  }

  saveBankDetail() async {
    if (formKey.currentState!.validate()) {
      formKey.currentState!.save();
      hideKeyboard(context);
      appStore.setLoading(true);

      MultipartRequest multiPartRequest = await getMultiPartRequest(
        'update-profile',
      );
      multiPartRequest.fields['username'] = getStringAsync(USER_NAME);
      multiPartRequest.fields['id'] = getIntAsync(USER_ID).toString();
      multiPartRequest.fields['contact_number'] = getStringAsync(
        USER_CONTACT_NUMBER,
      ).validate();
      multiPartRequest.fields['email'] = getStringAsync(USER_EMAIL);
      String ibanValue = bankIbanCon.text.trim();
      String swiftValue = bankSwiftCon.text.trim();
      multiPartRequest.fields['user_bank_account[bank_name]'] = bankNameCon.text
          .trim();
      multiPartRequest.fields['user_bank_account[account_holder_name]'] =
          nameCon.text.trim();
      multiPartRequest.fields['user_bank_account[account_number]'] = ibanValue;
      multiPartRequest.fields['user_bank_account[bank_code]'] = swiftValue;
      multiPartRequest.fields['user_bank_account[bank_address]'] = '';
      multiPartRequest.fields['user_bank_account[routing_number]'] = '';
      multiPartRequest.fields['user_bank_account[bank_iban]'] = ibanValue;
      multiPartRequest.fields['user_bank_account[bank_swift]'] = swiftValue;
      multiPartRequest.headers.addAll(buildHeaderTokens());
      sendMultiPartRequest(
        multiPartRequest,
        onSuccess: (data) async {
          if (data != null) {
            LoginResponse res = LoginResponse.fromJson(data);
            toast(res.message.toString());
            appStore.setLoading(false);
            finish(context);
          }
        },
        onError: (error) {
          log(multiPartRequest.toString());
          toast(error.toString(), print: true);
          appStore.setLoading(false);
        },
      ).catchError((e) {
        appStore.setLoading(false);
        toast(e.toString());
      });
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (context) {
        return CommonScaffoldComponent(
          appBarTitle: language.bankDetails,
          body: Stack(
            children: [
              SingleChildScrollView(
                padding: .symmetric(horizontal: 16, vertical: 8),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: .start,
                    children: [
                      8.height,
                      Text('Account Holder Name', style: primaryTextStyle()),
                      8.height,
                      AppTextField(
                        isValidationRequired: true,
                        controller: nameCon,
                        textFieldType: TextFieldType.NAME,
                        errorThisFieldRequired: language.fieldRequiredMsg,
                        decoration: commonInputDecoration(
                          hintText: 'Account Holder Name',
                        ),
                      ),
                      16.height,
                      Text('IBAN', style: primaryTextStyle()),
                      8.height,
                      AppTextField(
                        isValidationRequired: true,
                        controller: bankIbanCon,
                        textFieldType: TextFieldType.NAME,
                        errorThisFieldRequired: language.fieldRequiredMsg,
                        decoration: commonInputDecoration(hintText: 'IBAN'),
                      ),
                      16.height,
                      Text('BIC / SWIFT Code', style: primaryTextStyle()),
                      8.height,
                      AppTextField(
                        isValidationRequired: true,
                        controller: bankSwiftCon,
                        textFieldType: TextFieldType.NAME,
                        errorThisFieldRequired: language.fieldRequiredMsg,
                        decoration: commonInputDecoration(
                          hintText: 'BIC / SWIFT Code',
                        ),
                      ),
                      16.height,
                      Text(language.bankName, style: primaryTextStyle()),
                      8.height,
                      AppTextField(
                        isValidationRequired: true,
                        controller: bankNameCon,
                        textFieldType: TextFieldType.NAME,
                        errorThisFieldRequired: language.fieldRequiredMsg,
                        decoration: commonInputDecoration(
                          hintText: language.bankName,
                        ),
                      ),
                      30.height,
                    ],
                  ),
                ),
              ),
              loaderWidget().visible(appStore.isLoading),
            ],
          ),
          bottomNavigationBar: AppButton(
            color: ColorUtils.colorPrimary,
            textColor: Colors.white,
            text: language.save,
            onTap: () {
              saveBankDetail();
            },
          ).paddingAll(16),
        );
      },
    );
  }
}
