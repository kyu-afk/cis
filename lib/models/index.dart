export 'sandi_bank_model.dart';
export 'kantor_model.dart';
export 'users_model.dart';
export 'users_access_model.dart';
export 'fasilitas_add_model.dart';
export 'fasilitas_model.dart';
import 'package:quiver/core.dart';

T? checkOptional<T>(Optional<T?>? optional, T? Function()? def) {
  // No value given, just take default value
  if (optional == null) return def?.call();

  // We have an input value
  if (optional.isPresent) return optional.value;

  // We have a null inside the optional
  return null;
}
