//
//  FilterPresets.swift
//  iina
//
//  Created by lhc on 25/8/2017.
//  Copyright © 2017 lhc. All rights reserved.
//

import Foundation

fileprivate typealias PM = FilterParameter

class FilterPreset {
  typealias Transformer = (FilterPresetInstance) -> MPVFilter

  private static let defaultTransformer: Transformer = { instance in
    return MPVFilter(lavfiFilterFromPresetInstance: instance)
  }

  var name: String
  var params: [String: FilterParameter]
  var paramOrder: [String]?
  var transformer: Transformer

  var localizedName: String {
    return FilterPreset.l10nDic[name] ?? name
  }

  init(_ name: String,
       params: [String: FilterParameter],
       paramOrder: String? = nil,
       transformer: @escaping Transformer = FilterPreset.defaultTransformer) {
    self.name = name
    self.params = params
    self.paramOrder = paramOrder?.components(separatedBy: ":")
    self.transformer = transformer
  }

  func localizedParamName(_ param: String) -> String {
    return FilterPreset.l10nDic["\(name).\(param)"] ?? param
  }
}

class FilterPresetInstance {
  var preset: FilterPreset
  var params: [String: FilterParamaterValue] = [:]

  init(from preset: FilterPreset) {
    self.preset = preset
  }

  func value(for name: String) -> FilterParamaterValue {
    return params[name] ?? preset.params[name]!.defaultValue
  }
}

class FilterParameter {
  enum ParamType {
    case text, int, float
  }
  var type: ParamType
  var defaultValue: FilterParamaterValue

  var min: Float?
  var max: Float?
  var minInt: Int?
  var maxInt: Int?
  var step: Int?

  static func text(defaultValue: String = "") -> FilterParameter {
    return FilterParameter(.text, defaultValue: FilterParamaterValue(string: defaultValue))
  }

  static func int(min: Int, max: Int, step: Int = 1, defaultValue: Int = 0) -> FilterParameter {
    let pm = FilterParameter(.int, defaultValue: FilterParamaterValue(int: defaultValue))
    pm.minInt = min
    pm.maxInt = max
    pm.step = step
    return pm
  }

  static func float(min: Float, max: Float, defaultValue: Float = 0) -> FilterParameter {
    let pm = FilterParameter(.float, defaultValue: FilterParamaterValue(float: defaultValue))
    pm.min = min
    pm.max = max
    return pm
  }


  private init(_ type: ParamType, defaultValue: FilterParamaterValue) {
    self.type = type
    self.defaultValue = defaultValue
  }
}

struct FilterParamaterValue {
  private var _stringValue: String?
  private var _intValue: Int?
  private var _floatValue: Float?

  var stringValue: String {
    return _stringValue ?? _intValue?.toStr() ?? _floatValue?.toStr() ?? ""
  }

  var intValue: Int {
    return _intValue ?? 0
  }

  var floatValue: Float {
    return _floatValue ?? 0
  }

  init(string: String) {
    self._stringValue = string
  }

  init(int: Int) {
    self._intValue = int
  }

  init(float: Float) {
    self._floatValue = float
  }
}


extension FilterPreset {
  static let l10nDic: [String: String] = {
    guard let filePath = Bundle.main.path(forResource: "FilterPresets", ofType: "strings"),
      let dic = NSDictionary(contentsOfFile: filePath) as? [String : String] else {
        return [:]
    }
    return dic
  }()

  static let presets: [FilterPreset] = [
    // crop
    FilterPreset("crop", params: [
      "x": PM.text(), "y": PM.text(),
      "w": PM.text(), "h": PM.text()
    ], paramOrder: "w:h:x:y") { instance in
      return MPVFilter(mpvFilterFromPresetInstance: instance)
    },
    // expand
    FilterPreset("expand", params: [
      "x": PM.text(), "y": PM.text(),
      "w": PM.text(), "h": PM.text(),
      "aspect": PM.text(defaultValue: "0"),
      "round": PM.text(defaultValue: "1")
    ], paramOrder: "w:h:x:y:aspect:round") { instance in
      return MPVFilter(mpvFilterFromPresetInstance: instance)
    },
    // sharpen
    FilterPreset("sharpen", params: [
      "amount": PM.float(min: 0, max: 1.5),
      "msize": PM.int(min: 3, max: 23, step: 2, defaultValue: 5)
    ]) { instance in
      return MPVFilter.unsharp(amount: instance.value(for: "amount").floatValue,
                               msize: instance.value(for: "msize").intValue)
    },
    // blur
    FilterPreset("blur", params: [
      "amount": PM.float(min: 0, max: 1.5),
      "msize": PM.int(min: 3, max: 23, step: 2, defaultValue: 5)
    ]) { instance in
      return MPVFilter.unsharp(amount: -instance.value(for: "amount").floatValue,
                               msize: instance.value(for: "msize").intValue)
    },
    // delogo
    FilterPreset("delogo", params: [
      "x": PM.text(defaultValue: "1"),
      "y": PM.text(defaultValue: "1"),
      "w": PM.text(defaultValue: "1"),
      "h": PM.text(defaultValue: "1")
    ], paramOrder: "x:y:w:h"),
    // invert color
    FilterPreset("negative", params: [:]) { instance in
      return MPVFilter(lavfiName: "lutrgb", label: nil, paramDict: [
          "r": "negval", "g": "negval", "b": "negval"
        ])
    },
    // flip
    FilterPreset("vflip", params: [:]) { instance in
      return MPVFilter(mpvFilterFromPresetInstance: instance)
    },
    // mirror
    FilterPreset("hflip", params: [:]) { instance in
      return MPVFilter(mpvFilterFromPresetInstance: instance)
    },
    // custom mpv
    FilterPreset("custom_mpv", params: [
      "name": PM.text(defaultValue: ""),
      "string": PM.text(defaultValue: "")
    ]) { instance in
      return MPVFilter(rawString: instance.value(for: "name").stringValue + "=" + instance.value(for: "string").stringValue)!
    },
    // custom ffmpeg
    FilterPreset("custom_ffmpeg", params: [
      "name": PM.text(defaultValue: ""),
      "string": PM.text(defaultValue: "")
    ]) { instance in
      return MPVFilter(name: "lavfi", label: nil,
                       paramString: "[\(instance.value(for: "name").stringValue)=\(instance.value(for: "string").stringValue)]")
    },
  ]
}
