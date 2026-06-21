import 'package:flutter/material.dart';

import 'colors.dart';

class ButtonIcon extends StatelessWidget {
  final IconData icon;

  const ButtonIcon({super.key, required this.icon});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorPrimary,
                colorPrimaryLight,
              ])),
      child: Icon(
        icon,
        color: colortextwhite,
      ),
    );
  }
}

class ButtonPrimary extends StatelessWidget {
  final String? name;
  final Function onTap;
  const ButtonPrimary({super.key, this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorPrimary,
          border: Border.all(
            width: 2,
            color: colorPrimary,
          ),
        ),
        child: Text(
          "$name",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: colortextwhite,
          ),
        ),
      ),
    );
  }
}

class ButtonPrimaryNoRounded extends StatelessWidget {
  final String? name;
  final Function onTap;
  const ButtonPrimaryNoRounded({super.key, this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
           border: Border.all(
            width: 1,
            color: colorPrimaryLight
           )),
        child: Text(
          "$name",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class ButtonSecondary extends StatelessWidget {
  final String? name;
  final Function onTap;
  const ButtonSecondary({super.key, this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorError,
          border: Border.all(
            width: 2,
            color: colorError,
          ),
        ),
        child: Text(
          "$name",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: colortextwhite,
          ),
        ),
      ),
    );
  }
}

class ButtonDelete extends StatelessWidget {
  final String? name;
  final Function onTap;
  const ButtonDelete({super.key, this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorError,
          border: Border.all(
            width: 2,
            color: colorError,
          ),
        ),
        child: Text(
          "$name",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: colortextwhite,
          ),
        ),
      ),
    );
  }
}

class ButtonProcess extends StatelessWidget {
  final String? name;
  final Function onTap;
  const ButtonProcess({super.key, this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: colorAccent,
          border: Border.all(
            width: 2,
            color: colorAccent,
          ),
        ),
        child: Text(
          "$name",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class ButtonClose extends StatelessWidget {
  final String? name;
  final Function onTap;
  const ButtonClose({super.key, this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onTap(),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: Colors.black,
          border: Border.all(
            width: 2,
            color: Colors.black,
          ),
        ),
        child: Text(
          "$name",
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: colortextwhite,
          ),
        ),
      ),
    );
  }
}

