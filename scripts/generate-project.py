#!/usr/bin/env python3
"""Generate an ordinary Xcode project without XcodeGen or external libraries."""
from pathlib import Path
import hashlib, json, plistlib, math, struct, zlib
root = Path(__file__).resolve().parent.parent
objects = {}
def key(name): return hashlib.sha1(name.encode()).hexdigest()[:24].upper()
def add(object_name, isa, **fields):
    identifier = key(object_name); objects[identifier] = dict(isa=isa, **fields); return identifier

def encode(value, level=0):
    if isinstance(value, dict): return '{\n' + ''.join('\t'*(level+1) + str(k) + ' = ' + encode(v, level+1) + ';\n' for k,v in value.items()) + '\t'*level + '}'
    if isinstance(value, list): return '(' + ', '.join(encode(v, level+1) for v in value) + ')'
    return json.dumps(str(value), ensure_ascii=False)

sources=[]; source_build=[]; resources=[]; resource_build=[]
for path in sorted(list((root/'App').rglob('*.swift')) + list((root/'Sources/ParcelCore').glob('*.swift'))):
    relative = str(path.relative_to(root))
    ref = add('file:'+relative, 'PBXFileReference', lastKnownFileType='sourcecode.swift', path=relative, sourceTree='<group>')
    sources.append(ref); source_build.append(add('build:'+relative, 'PBXBuildFile', fileRef=ref))
for relative, kind in [('App/Resources/Assets.xcassets', 'folder.assetcatalog'), ('App/Resources/PrivacyInfo.xcprivacy', 'text.xml')]:
    ref=add('file:'+relative, 'PBXFileReference', lastKnownFileType=kind, path=relative, sourceTree='<group>')
    resources.append(ref); resource_build.append(add('build:'+relative, 'PBXBuildFile', fileRef=ref))
if (root/'App/Resources/GoogleService-Info.plist').exists():
    relative='App/Resources/GoogleService-Info.plist'
    ref=add('file:'+relative, 'PBXFileReference', lastKnownFileType='text.plist.xml', path=relative, sourceTree='<group>')
    resources.append(ref); resource_build.append(add('build:'+relative, 'PBXBuildFile', fileRef=ref))
product=add('product', 'PBXFileReference', explicitFileType='wrapper.application', path='JolParcel.app', sourceTree='BUILT_PRODUCTS_DIR')
products=add('products', 'PBXGroup', children=[product], name='Products', sourceTree='<group>')
source_group=add('sources', 'PBXGroup', children=sources, name='Sources', sourceTree='<group>')
resource_group=add('resources', 'PBXGroup', children=resources, name='Resources', sourceTree='<group>')
signing_config=add('signing-config', 'PBXFileReference', lastKnownFileType='text.xcconfig', path='App/Resources/Signing.xcconfig', sourceTree='<group>')
main_group=add('main', 'PBXGroup', children=[source_group,resource_group,products,signing_config], sourceTree='<group>')
package=add('firebase-package', 'XCRemoteSwiftPackageReference', repositoryURL='https://github.com/firebase/firebase-ios-sdk.git', requirement={'kind':'upToNextMajorVersion','minimumVersion':'12.0.0'})
deps=[]; frameworks=[]
for product_name in ['FirebaseAuth','FirebaseFirestore','FirebaseStorage','FirebaseFunctions','FirebaseMessaging','FirebaseAppCheck']:
    dep=add('dependency:'+product_name, 'XCSwiftPackageProductDependency', package=package, productName=product_name)
    deps.append(dep); frameworks.append(add('framework:'+product_name,'PBXBuildFile', productRef=dep))
phases=[add('source-phase','PBXSourcesBuildPhase',buildActionMask='2147483647',files=source_build,runOnlyForDeploymentPostprocessing='0'),add('framework-phase','PBXFrameworksBuildPhase',buildActionMask='2147483647',files=frameworks,runOnlyForDeploymentPostprocessing='0'),add('resource-phase','PBXResourcesBuildPhase',buildActionMask='2147483647',files=resource_build,runOnlyForDeploymentPostprocessing='0')]
project_configs=[]; target_configs=[]
for configuration in ['Debug','Release','Demo']:
    settings={'IPHONEOS_DEPLOYMENT_TARGET':'17.0','SDKROOT':'iphoneos','SWIFT_VERSION':'5.0','CLANG_ENABLE_MODULES':'YES','ONLY_ACTIVE_ARCH':'YES' if configuration!='Release' else 'NO','SWIFT_OPTIMIZATION_LEVEL':'-Onone' if configuration!='Release' else '-O','SWIFT_ACTIVE_COMPILATION_CONDITIONS':'DEBUG JOL_DEMO_ONLY' if configuration=='Demo' else ('DEBUG' if configuration=='Debug' else '')}
    project_configs.append(add('project-config:'+configuration,'XCBuildConfiguration',name=configuration,buildSettings=settings))
    target_settings={'PRODUCT_BUNDLE_IDENTIFIER':'kz.jol.parcel','PRODUCT_NAME':'$(TARGET_NAME)','GENERATE_INFOPLIST_FILE':'NO','INFOPLIST_FILE':'App/Resources/Info.plist','CODE_SIGN_ENTITLEMENTS':'App/Resources/JolParcel.entitlements','CODE_SIGN_STYLE':'Automatic','TARGETED_DEVICE_FAMILY':'1','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon','LD_RUNPATH_SEARCH_PATHS':['$(inherited)','@executable_path/Frameworks'],'SUPPORTS_MACCATALYST':'NO','APS_ENVIRONMENT':'development' if configuration!='Release' else 'production','APP_ATTEST_ENVIRONMENT':'development' if configuration!='Release' else 'production'}
    if configuration == 'Demo':
        target_settings.update(PRODUCT_BUNDLE_IDENTIFIER='kz.jol.parcel.demo', CODE_SIGN_ENTITLEMENTS='App/Resources/Demo.entitlements')
    target_configs.append(add('target-config:'+configuration,'XCBuildConfiguration',name=configuration,baseConfigurationReference=signing_config,buildSettings=target_settings))
pc=add('project-configs','XCConfigurationList',buildConfigurations=project_configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
tc=add('target-configs','XCConfigurationList',buildConfigurations=target_configs,defaultConfigurationIsVisible='0',defaultConfigurationName='Release')
target=add('target','PBXNativeTarget',buildConfigurationList=tc,buildPhases=phases,buildRules=[],dependencies=[],name='JolParcel',packageProductDependencies=deps,productName='JolParcel',productReference=product,productType='com.apple.product-type.application')
project=add('project','PBXProject',attributes={'LastUpgradeCheck':'2600','TargetAttributes':{target:{'CreatedOnToolsVersion':'26.0'}}},buildConfigurationList=pc,compatibilityVersion='Xcode 14.0',developmentRegion='ru',hasScannedForEncodings='0',knownRegions=['ru','Base'],mainGroup=main_group,packageReferences=[package],productRefGroup=products,projectDirPath='',projectRoot='',targets=[target])
folder=root/'JolParcel.xcodeproj'; folder.mkdir(exist_ok=True)
(folder/'project.pbxproj').write_text('// !$*UTF8*$!\n'+encode({'archiveVersion':'1','classes':{},'objectVersion':'56','objects':objects,'rootObject':project})+'\n')
scheme=folder/'xcshareddata/xcschemes'; scheme.mkdir(parents=True,exist_ok=True)
scheme_xml=f'''<?xml version="1.0" encoding="UTF-8"?>
<Scheme LastUpgradeVersion="2600" version="1.3">
<BuildAction parallelizeBuildables="YES" buildImplicitDependencies="YES"><BuildActionEntries><BuildActionEntry buildForTesting="YES" buildForRunning="YES" buildForProfiling="YES" buildForArchiving="YES" buildForAnalyzing="YES"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="JolParcel.app" BlueprintName="JolParcel" ReferencedContainer="container:JolParcel.xcodeproj"/></BuildActionEntry></BuildActionEntries></BuildAction>
<LaunchAction buildConfiguration="Debug" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" launchStyle="0" useCustomWorkingDirectory="NO" ignoresPersistentStateOnLaunch="NO" debugDocumentVersioning="YES" debugServiceExtension="internal" allowLocationSimulation="YES"><BuildableProductRunnable runnableDebuggingMode="0"><BuildableReference BuildableIdentifier="primary" BlueprintIdentifier="{target}" BuildableName="JolParcel.app" BlueprintName="JolParcel" ReferencedContainer="container:JolParcel.xcodeproj"/></BuildableProductRunnable></LaunchAction>
<ProfileAction buildConfiguration="Release" shouldUseLaunchSchemeArgsEnv="YES" savedToolIdentifier="" useCustomWorkingDirectory="NO" debugDocumentVersioning="YES"/>
<AnalyzeAction buildConfiguration="Debug"/><ArchiveAction buildConfiguration="Release" revealArchiveInOrganizer="YES"/>
</Scheme>'''
if not (scheme/'JolParcel.xcscheme').exists():
    (scheme/'JolParcel.xcscheme').write_text(scheme_xml)
(scheme/'JolParcelDemo.xcscheme').write_text(scheme_xml.replace('buildConfiguration="Debug"', 'buildConfiguration="Demo"').replace('buildConfiguration="Release"', 'buildConfiguration="Demo"').replace('<LaunchAction', '<TestAction buildConfiguration="Demo" selectedDebuggerIdentifier="Xcode.DebuggerFoundation.Debugger.LLDB" selectedLauncherIdentifier="Xcode.IDEFoundation.Launcher.LLDB" shouldUseLaunchSchemeArgsEnv="YES" shouldAutocreateTestPlan="YES"/><LaunchAction'))
print(folder)
