// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'transaction_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TransactionModelAdapter extends TypeAdapter<TransactionModel> {
  @override
  final int typeId = 0;

  @override
  TransactionModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TransactionModel(
      id: fields[0] as String,
      amount: fields[1] as double,
      type: fields[2] as String,
      appSource: fields[3] as String,
      payerName: fields[4] as String,
      dateTime: fields[5] as DateTime,
      rawMessage: fields[6] as String,
      appPackage: fields[7] as String,
      webhookStatus: fields[8] as String,
      webhookHttpCode: fields[9] as int?,
      webhookError: fields[10] as String?,
      webhookSentAt: fields[11] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, TransactionModel obj) {
    writer
      ..writeByte(12)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.appSource)
      ..writeByte(4)
      ..write(obj.payerName)
      ..writeByte(5)
      ..write(obj.dateTime)
      ..writeByte(6)
      ..write(obj.rawMessage)
      ..writeByte(7)
      ..write(obj.appPackage)
      ..writeByte(8)
      ..write(obj.webhookStatus)
      ..writeByte(9)
      ..write(obj.webhookHttpCode)
      ..writeByte(10)
      ..write(obj.webhookError)
      ..writeByte(11)
      ..write(obj.webhookSentAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TransactionModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
