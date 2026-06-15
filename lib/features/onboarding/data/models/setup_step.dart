enum SetupStep {
  welcome(0),
  premium(1),
  username(2),
  directories(3),
  complete(4);

  final int stepIndex;
  const SetupStep(this.stepIndex);

  static SetupStep fromIndex(int index) {
    return SetupStep.values.firstWhere(
      (step) => step.stepIndex == index,
      orElse: () => SetupStep.welcome,
    );
  }

  SetupStep get next {
    final nextIndex = stepIndex + 1;
    if (nextIndex >= SetupStep.values.length) {
      return complete;
    }
    return SetupStep.values[nextIndex];
  }

  SetupStep get previous {
    final prevIndex = stepIndex - 1;
    if (prevIndex < 0) return welcome;
    return SetupStep.values[prevIndex];
  }

  bool get isLast => this == complete;
}
